// Package helmupgrade hatches a helm chart upgrade to equilibrium.
// After the chart has been downloaded and files patched by the upgrade task,
// this command brings the workspace to a consistent, validated state.
package helmupgrade

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/defn/other/m/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

type Config struct {
	Apps []string
}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)

	if len(cfg.Apps) == 0 {
		return fmt.Errorf("usage: defn hatch helm-upgrade <app> [app...]")
	}

	// Read the per-tenant registry-mirror prefix from the merged catalog
	// once up front; image-set normalization below strips it before
	// comparing pre-/post-upgrade refs. Empty means "no mirror" and the
	// strip is a no-op. Per AIDR-00142.
	genCtx, err := gen.NewContext(".", nil)
	if err != nil {
		return fmt.Errorf("init catalog: %w", err)
	}
	mirrorPrefix := genCtx.MirrorPrefix()

	for _, app := range cfg.Apps {
		if err := hatchApp(app, mirrorPrefix); err != nil {
			return fmt.Errorf("hatch helm-upgrade %s: %w", app, err)
		}
	}
	return nil
}

func hatchApp(appName, mirrorPrefix string) error {
	appPath := filepath.Join("tenant", "library", "app", appName)

	// Save pre-hatch image set from the old gen-app.cue.
	oldImages := extractImages(filepath.Join(appPath, "gen-app.cue"))

	// Phase 0: align mirror_images tags with the new chart. The helm-upgrade
	// task has already rewritten kustomization.yaml newTag fields to the
	// target version; walk that file and bump the matching catalog entries
	// (source + tag + digest) atomically. Source migrations -- registry
	// moves where the tag is unchanged -- are left for Phase 2 below.
	if n, err := stamp.BumpMirrorTagsFromKustomization(".", appName); err != nil {
		return fmt.Errorf("bump mirror tags: %w", err)
	} else if n > 0 {
		fmt.Printf("\u2713 %s: bumped %d mirror_images tag(s)\n", appName, n)
	}

	// Phase 1: hatch cycle to reach equilibrium with the new chart.
	fmt.Printf("\u2713 %s: hatching to equilibrium...\n", appName)
	if _, err := hatchlib.Cycle(); err != nil {
		return fmt.Errorf("hatch cycle: %w", err)
	}

	// Phase 2: detect image source changes.
	newImages := extractImages(filepath.Join(appPath, "gen-app.cue"))
	changed := detectImageChanges(oldImages, newImages, mirrorPrefix)

	if len(changed) > 0 {
		for _, ch := range changed {
			// Update app.cue: replace old source with new.
			appCuePath := filepath.Join(appPath, "app.cue")
			if err := replaceInFile(appCuePath, ch.oldSource, ch.newSource); err != nil {
				return fmt.Errorf("update app.cue: %w", err)
			}
			fmt.Printf("\u2713 %s: updated app.cue image %s -> %s\n", appName, ch.oldSource, ch.newSource)

			// Update mirrors.cue: replace source and resolve new digest.
			digest, err := craneDigest(ch.newSource + ":" + ch.tag)
			if err != nil {
				return fmt.Errorf("crane digest %s:%s: %w", ch.newSource, ch.tag, err)
			}
			mirrorsPath := "kernel/catalog/mirrors.cue"
			if err := replaceInFile(mirrorsPath, ch.oldSource, ch.newSource); err != nil {
				return fmt.Errorf("update mirrors.cue source: %w", err)
			}
			if err := updateMirrorDigest(mirrorsPath, ch.newSource, ch.tag, digest); err != nil {
				return fmt.Errorf("update mirrors.cue digest: %w", err)
			}
			fmt.Printf("\u2713 %s: updated mirrors.cue with digest for %s\n", appName, ch.newSource)
		}

		// Phase 3: re-hatch with corrected image sources.
		fmt.Printf("\u2713 %s: re-hatching with updated image sources...\n", appName)
		if _, err := hatchlib.Cycle(); err != nil {
			return fmt.Errorf("re-hatch cycle: %w", err)
		}
	}

	// Phase 4: validate with full pipeline.
	fmt.Printf("\u2713 %s: validating...\n", appName)
	if err := hatchlib.CycleAndValidate(); err != nil {
		return fmt.Errorf("validate: %w", err)
	}

	return nil
}

// imageChange represents a detected image registry change.
type imageChange struct {
	oldSource string
	newSource string
	tag       string
}

// extractImages reads image: "..." lines from a gen-app.cue file.
func extractImages(path string) map[string]bool {
	images := map[string]bool{}
	f, err := os.Open(path)
	if err != nil {
		return images
	}
	defer f.Close()

	re := regexp.MustCompile(`image:\s+"([^"]+)"`)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if m := re.FindStringSubmatch(scanner.Text()); len(m) > 1 {
			images[m[1]] = true
		}
	}
	return images
}

// detectImageChanges finds images where the source (registry) changed
// but the tag stayed the same -- indicating a chart registry migration.
// mirrorPrefix comes from the catalog's mirror_prefix scalar
// (AIDR-00142); when empty, the normalization is a no-op.
func detectImageChanges(oldImages, newImages map[string]bool, mirrorPrefix string) []imageChange {
	stripMirror := func(img string) string {
		if mirrorPrefix == "" {
			return img
		}
		return strings.TrimPrefix(img, mirrorPrefix)
	}

	// Normalize both sets by stripping mirror prefix.
	oldStripped := map[string]bool{}
	for img := range oldImages {
		oldStripped[stripMirror(img)] = true
	}
	newStripped := map[string]bool{}
	for img := range newImages {
		newStripped[stripMirror(img)] = true
	}

	// Find images added (in new but not old) and removed (in old but not new).
	var added, removed []string
	for img := range newStripped {
		if !oldStripped[img] {
			added = append(added, img)
		}
	}
	for img := range oldStripped {
		if !newStripped[img] {
			removed = append(removed, img)
		}
	}

	var changes []imageChange
	for _, newImg := range added {
		newTag := tagOf(newImg)
		for _, oldImg := range removed {
			if tagOf(oldImg) == newTag {
				changes = append(changes, imageChange{
					oldSource: sourceOf(oldImg),
					newSource: sourceOf(newImg),
					tag:       newTag,
				})
				break
			}
		}
	}
	return changes
}

func tagOf(img string) string {
	parts := strings.Split(img, ":")
	if len(parts) > 1 {
		return parts[len(parts)-1]
	}
	return "latest"
}

func sourceOf(img string) string {
	parts := strings.Split(img, ":")
	if len(parts) > 1 {
		return strings.Join(parts[:len(parts)-1], ":")
	}
	return img
}

func replaceInFile(path, old, new string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	result := strings.ReplaceAll(string(data), old, new)
	return os.WriteFile(path, []byte(result), 0o644)
}

func craneDigest(ref string) (string, error) {
	return runner.Output(context.Background(), runner.Opts{
		Args: []string{"crane", "digest", ref},
	})
}

func updateMirrorDigest(path, source, tag, digest string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	// Match the digest field within the entry for this source:tag.
	pat := `(?m)("%s:%s"[^}]*digest:\s+")[^"]*(")`
	pattern := fmt.Sprintf(pat, regexp.QuoteMeta(source), regexp.QuoteMeta(tag))
	re := regexp.MustCompile(pattern)
	result := re.ReplaceAllString(string(data), "${1}"+digest+"${2}")
	return os.WriteFile(path, []byte(result), 0o644)
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, args []string) Config {
	return Config{Apps: args}
}

func RegisterFlags(_ *cobra.Command) {}
