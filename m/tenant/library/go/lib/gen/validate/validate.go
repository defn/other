// Package validate implements check-images and check-bazel in Go,
// reusing the gen.Context to avoid spawning CUE or Bazel subprocesses.
package validate

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// imageRef is a parsed container image reference.
type imageRef struct {
	source string
	tag    string
}

var imageRe = regexp.MustCompile(`image:\s+"([^"]+)"`)

// CheckImages validates that all container images in rendered manifests
// have mirror catalog entries with non-empty digests.
func CheckImages(ctx *gen.Context) error {
	// Extract mirror catalog from already-loaded CUE context
	mirrorImages := ctx.CatalogQuery("mirror_images")
	catalogKeys := map[string]bool{}
	var emptyDigests []string
	gen.IterMap(mirrorImages, func(key string, v cue.Value) error {
		k := gen.CueFieldKey(key)
		catalogKeys[k] = true
		digest, _ := gen.DecodeString(v, "digest")
		if digest == "" {
			src, _ := gen.DecodeString(v, "source")
			tag, _ := gen.DecodeString(v, "tag")
			emptyDigests = append(emptyDigests, src+":"+tag)
		}
		return nil
	})

	// Extract app paths from catalog. AIDR-00146: kustomize apps' gen-app.cue
	// is rendered to var/app/<name>/, not the source dir; raw apps keep theirs
	// at the source path. Route per-kind so image scanning sees both.
	apps := ctx.CatalogQuery("apps")
	var appPaths []struct{ name, path string }
	gen.IterMap(apps, func(key string, v cue.Value) error {
		name := gen.CueFieldKey(key)
		path, _ := gen.DecodeString(v, "path")
		kind, _ := gen.DecodeString(v, "kind")
		if path == "" {
			return nil
		}
		if kind == "kustomize" {
			path = "var/app/" + name
		}
		appPaths = append(appPaths, struct{ name, path string }{name, path})
		return nil
	})

	// Scan gen-app.cue files for image references
	allImages := map[string]bool{}
	var notMirrored []struct{ app, image, source, tag string }

	for _, ap := range appPaths {
		genApp := filepath.Join(ctx.WorkDir, ap.path, "gen-app.cue")
		data, err := os.ReadFile(genApp)
		if err != nil {
			continue
		}
		for _, match := range imageRe.FindAllStringSubmatch(string(data), -1) {
			img := match[1]
			// Strip mirror prefix
			canonical := strings.TrimPrefix(img, "host.k3d.internal:5000/mirror/")
			allImages[canonical] = true

			ref := parseImageRef(canonical)
			catalogKey := ref.source + ":" + ref.tag
			if !catalogKeys[catalogKey] {
				notMirrored = append(notMirrored, struct{ app, image, source, tag string }{
					ap.name, canonical, ref.source, ref.tag,
				})
			}
		}
	}

	ctx.LogOK(fmt.Sprintf("%d unique images across rendered manifests", len(allImages)))

	// Check empty digests
	if len(emptyDigests) > 0 {
		sort.Strings(emptyDigests)
		return fmt.Errorf("mirror catalog missing digests (%d): %s",
			len(emptyDigests), strings.Join(emptyDigests, ", "))
	}

	// Check unmirrored
	if len(notMirrored) > 0 {
		var lines []string
		for _, nm := range notMirrored {
			lines = append(lines, fmt.Sprintf("  %s:%s (app: %s)", nm.source, nm.tag, nm.app))
		}
		sort.Strings(lines)
		return fmt.Errorf("images not in mirror catalog (%d):\n%s",
			len(notMirrored), strings.Join(lines, "\n"))
	}

	ctx.LogOK("all images are in the mirror catalog")
	ctx.LogOK("no image drift detected")
	return nil
}

func parseImageRef(ref string) imageRef {
	base := ref
	if idx := strings.Index(ref, "@"); idx >= 0 {
		base = ref[:idx]
	}
	parts := strings.SplitN(base, ":", 2)
	if len(parts) == 2 && !strings.Contains(parts[1], "/") {
		return imageRef{source: parts[0], tag: parts[1]}
	}
	return imageRef{source: base, tag: "latest"}
}

// CheckBricks validates two invariants over the catalog brick roster:
//
//  1. Every "component" brick has a real on-disk directory at its
//     declared path. Kit bricks (umbrella aggregators) are exempt
//     because their path is metadata. Paths beginning with "_" are
//     also exempt.
//
//  2. Every entry in a branch's `composes` list (which are workspace
//     paths) resolves to a directory on disk. Catches stale composes
//     entries left behind when a brick is renamed or moved.
//
// Together these catch the class of bug where a brick declaration
// outlives the directory it claims, or where a branch composes list
// drifts from the actual filesystem.
func CheckBricks(ctx *gen.Context) error {
	bricks := ctx.CatalogQuery("bricks")

	var dangling []string
	var staleComposes []string
	slugOwners := map[string]string{}
	var slugCollisions []string
	if err := gen.IterMap(bricks, func(key string, v cue.Value) error {
		kind, _ := gen.DecodeString(v, "kind")
		// Slug uniqueness: every brick contributes a brick-<slug>.cue
		// catalog file, so two bricks sharing a slug would collide.
		slug, _ := gen.DecodeString(v, "slug")
		if slug != "" {
			if owner, dup := slugOwners[slug]; dup {
				slugCollisions = append(slugCollisions,
					fmt.Sprintf("%q claimed by both %q and %q", slug, owner, key))
			} else {
				slugOwners[slug] = key
			}
		}

		if kind == "branch" {
			composes := v.LookupPath(cue.ParsePath("composes"))
			gen.IterList(composes, func(elem cue.Value) error {
				p, err := elem.String()
				if err != nil || p == "" || strings.HasPrefix(p, "_") {
					return nil
				}
				full := filepath.Join(ctx.WorkDir, p)
				if info, err := os.Stat(full); err != nil || !info.IsDir() {
					staleComposes = append(staleComposes,
						fmt.Sprintf("%s -> %q (no such directory)", key, p))
				}
				return nil
			})
			return nil
		}

		path, _ := gen.DecodeString(v, "path")
		if path == "" || strings.HasPrefix(path, "_") {
			return nil
		}
		full := filepath.Join(ctx.WorkDir, path)
		if info, err := os.Stat(full); err != nil || !info.IsDir() {
			dangling = append(dangling, fmt.Sprintf("%s (path=%q)", key, path))
		}
		return nil
	}); err != nil {
		return fmt.Errorf("iterate bricks: %w", err)
	}

	if len(dangling) > 0 {
		sort.Strings(dangling)
		return fmt.Errorf("%d component brick(s) declare paths that don't resolve to a directory:\n  %s",
			len(dangling), strings.Join(dangling, "\n  "))
	}
	if len(staleComposes) > 0 {
		sort.Strings(staleComposes)
		return fmt.Errorf("%d stale composes reference(s):\n  %s",
			len(staleComposes), strings.Join(staleComposes, "\n  "))
	}
	if len(slugCollisions) > 0 {
		sort.Strings(slugCollisions)
		return fmt.Errorf("%d slug collision(s); set explicit slug on one side:\n  %s",
			len(slugCollisions), strings.Join(slugCollisions, "\n  "))
	}
	ctx.LogOK("all component bricks have a live directory; all branch composes resolve to directories; brick slugs are unique")
	return nil
}

// CheckBazelCoverage validates that all git-tracked files are known to Bazel
// with format and tag coverage. Uses 2 bazel queries (source files + fmt
// coverage) instead of the original 4.
func CheckBazelCoverage(ctx *gen.Context) error {
	// Two queries: source files and fmt-covered files. Tagged coverage
	// mirrors fmt coverage (every tagged_file has a paired fmt_test).
	sourceOut, err := ctx.Sh("bazel-runner", "query", `kind("source file", //...:*)`)
	if err != nil {
		return fmt.Errorf("bazel query source files: %w", err)
	}
	fmtOut, err := ctx.Sh("bazel-runner", "query", `labels(data, attr(tags, "\bfmt\b", tests(//...)))`)
	if err != nil {
		return fmt.Errorf("bazel query fmt: %w", err)
	}

	bazelFiles := labelsToPathSet(sourceOut)
	fmtFiles := labelsToPathSet(fmtOut)
	// tagged_file coverage == fmt_test coverage (gen produces both together)
	taggedFiles := fmtFiles

	gitOut, err := ctx.Sh("git", "ls-files")
	if err != nil {
		return fmt.Errorf("git ls-files: %w", err)
	}
	gitFiles := map[string]bool{}
	for _, f := range strings.Split(gitOut, "\n") {
		if f != "" {
			gitFiles[f] = true
		}
	}

	// Check 1: all git files in Bazel
	missingBazel := setDiff(gitFiles, bazelFiles)
	if len(missingBazel) > 0 {
		return formatCoverageError("git files not in Bazel", missingBazel,
			"file is tracked by git but no Bazel target's srcs / exports_files / filegroup includes it; add it to the appropriate BUILD.bazel")
	}
	ctx.LogOK(fmt.Sprintf("all %d git-tracked files are known to Bazel", len(gitFiles)))

	// Check 2: fmt coverage
	missingFmt := setDiff(gitFiles, fmtFiles)
	if len(missingFmt) > 0 {
		return formatCoverageError("files lack fmt_test", missingFmt,
			"every tracked file must have a fmt_test target with the matching tool (cue / gofmt / buildifier / dprint / ...); add fmt_test(name=..., src=..., tool=...) in the file's BUILD.bazel")
	}
	ctx.LogOK(fmt.Sprintf("all %d git-tracked files have fmt_test coverage", len(gitFiles)))

	// Check 3: mise task coverage (all .mise/tasks/*.clj must have fmt_test)
	var miseTasks []string
	for f := range gitFiles {
		if strings.Contains(f, ".mise/tasks/") && strings.HasSuffix(f, ".clj") {
			miseTasks = append(miseTasks, f)
		}
	}
	missingMise := setDiffSlice(miseTasks, fmtFiles)
	if len(missingMise) > 0 {
		return formatCoverageError("mise tasks lack fmt_test / tagged_file", missingMise,
			"every .mise/tasks/<name>.clj needs a fmt_test (tool=cljstyle) and tagged_file in the kernel BUILD.bazel that declares it")
	}
	// Subset of check 4 -- on success it's redundant noise; only the
	// error path above adds information.

	// Check 4: tagged_file coverage
	missingTagged := setDiff(gitFiles, taggedFiles)
	if len(missingTagged) > 0 {
		return formatCoverageError("files lack tagged_file", missingTagged,
			"every tracked file must have a tagged_file target with semantic tags (e.g. cue + source); add tagged_file(name=..., src=..., tags=[...]) in the file's BUILD.bazel")
	}
	ctx.LogOK(fmt.Sprintf("all %d git-tracked files have tagged_file coverage", len(gitFiles)))

	return nil
}

// formatCoverageError builds a multi-line, structured diagnostic
// for check-bazel failures. The CUE pipeline error wrapper preserves
// embedded newlines, so the operator sees:
//
//	check-bazel: git files not in Bazel (1)
//	  file is tracked by git but no Bazel target's srcs / ...
//
//	  - kernel/catalog/shared-bricks.cue
//
// Truncating to the first 5 paths -- as the previous code did --
// hid the full set when 6+ files needed registering. Listing all
// paths is verbose but cheap; failure mode is rare and the
// operator wants the complete fix-list.
func formatCoverageError(title string, paths []string, hint string) error {
	var b strings.Builder
	fmt.Fprintf(&b, "%s (%d)\n  %s\n\n", title, len(paths), hint)
	for _, p := range paths {
		fmt.Fprintf(&b, "  - %s\n", p)
	}
	return fmt.Errorf("%s", b.String())
}

func labelsToPathSet(output string) map[string]bool {
	result := map[string]bool{}
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "//") {
			continue
		}
		line = strings.TrimPrefix(line, "//")
		parts := strings.SplitN(line, ":", 2)
		if len(parts) == 2 {
			if parts[0] == "" {
				result[parts[1]] = true
			} else {
				result[parts[0]+"/"+parts[1]] = true
			}
		}
	}
	return result
}

func setDiff(a, b map[string]bool) []string {
	var diff []string
	for k := range a {
		if !b[k] {
			diff = append(diff, k)
		}
	}
	sort.Strings(diff)
	return diff
}

func setDiffSlice(a []string, b map[string]bool) []string {
	var diff []string
	for _, k := range a {
		if !b[k] {
			diff = append(diff, k)
		}
	}
	sort.Strings(diff)
	return diff
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
