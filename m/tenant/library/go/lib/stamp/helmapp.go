// Package stamp -- helmapp.go creates catalog entries for a new Helm chart app.
//
// `defn stamp helmapp <name>` automates the steps that turn a chart-repo
// URL into a fully-claimed brick. New apps land in the library tenant by
// default; cluster_digests entries (per-tenant deploy state) are seeded
// only on first stamp -- subsequent re-stamps for upgrades touch only
// the chart tarball, kernel/schema/versions.cue, and kernel/catalog/mirrors.cue.
//
//  1. Vendor the chart tarball into tenant/library/app/<name>/.
//  2. Discover container images via `helm template`, resolve digests.
//  3. Add or update image entries in kernel/catalog/mirrors.cue.
//  4. Add or update the version entry in kernel/schema/versions.cue
//     (chart_version + chart_sha256 are bumped on re-stamp).
//  5. Create per-app shard tenant/library/catalog/apps-<name>.cue (skip if exists).
//  6. Skip cluster_digests on re-stamp; on first stamp, surface a TODO
//     for the operator to seed entries in tenant/<tenant>/catalog/chart_versions.cue.
//  7. Scaffold tenant/library/app/<name>/app.cue (only on first run -- never overwritten).
//
// After stamping, the operator typically:
//
//   - Edits tenant/library/app/<name>/app.cue with app-specific config
//     (helm_values, route_mappings, workloads, secret_mappings, kustomize_patches).
//   - Adds a CRDs companion under tenant/library/app/<name>-crds/ if the chart has CRDs.
//   - Adds the app to a platform under k8s_platforms (e.g. k3d-base, k3d-jianghu).
//   - Runs `mise run hatch` then `mise run gen` to reach equilibrium.
//
// Re-running stamp with a new --chart-version refreshes the chart tarball,
// updates chart_version + chart_sha256 in versions.cue, and refreshes
// mirror entries. The hand-edited app.cue is preserved. Use
// `defn hatch helmupgrade <name>` after re-stamping to reach equilibrium.
//
// app.cue is the ONLY hand-edited file per app. Everything else is
// derived from it, the catalog, and the mirror catalog. Stamp is online
// (network-allowed); the equilibrium machinery (gen, hatch) is offline.
package stamp

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// HelmAppConfig holds configuration for stamping a Helm chart app.
type HelmAppConfig struct {
	Name         string
	ChartRepo    string
	ChartName    string
	ChartVersion string
	Desc         string
}

// StampHelmApp creates or updates all catalog entries for a Helm chart app.
func StampHelmApp(rootDir string, cfg HelmAppConfig) error {
	if cfg.Name == "" {
		return fmt.Errorf("app name is required")
	}
	if cfg.ChartRepo == "" || cfg.ChartName == "" || cfg.ChartVersion == "" {
		return fmt.Errorf("--chart-repo, --chart-name, and --chart-version are required")
	}
	if cfg.Desc == "" {
		cfg.Desc = cfg.Name
	}

	appDir := filepath.Join(rootDir, "tenant", "library", "app", cfg.Name)
	if err := os.MkdirAll(appDir, 0o755); err != nil {
		return fmt.Errorf("mkdir tenant/library/app/%s: %w", cfg.Name, err)
	}

	// Step 1: Vendor chart and compute SHA256.
	tgzPath, sha, err := vendorChart(rootDir, appDir, cfg)
	if err != nil {
		return fmt.Errorf("vendor chart: %w", err)
	}
	fmt.Printf("  vendored %s (sha256: %s)\n", filepath.Base(tgzPath), sha)

	// Extract appVersion from Chart.yaml inside the tarball.
	appVersion, err := extractAppVersion(tgzPath)
	if err != nil {
		// Fall back to chart version if appVersion not found.
		appVersion = cfg.ChartVersion
	}

	// Step 2: Discover container images.
	images, err := discoverImages(rootDir, cfg.Name, tgzPath)
	if err != nil {
		return fmt.Errorf("discover images: %w", err)
	}
	fmt.Printf("  discovered %d image(s)\n", len(images))

	// Step 3: Resolve digests and append to mirrors.cue.
	if err := appendMirrors(rootDir, images); err != nil {
		return fmt.Errorf("append mirrors: %w", err)
	}

	// Step 4: Add version entry to schema/versions.cue.
	if err := appendVersion(rootDir, cfg, sha, appVersion); err != nil {
		return fmt.Errorf("append version: %w", err)
	}

	// Step 5: Add app entry to catalog/apps.cue.
	if err := appendApp(rootDir, cfg); err != nil {
		return fmt.Errorf("append app: %w", err)
	}

	// Step 6: Add chart_versions entry to catalog/catalog.cue.
	if err := appendChartVersion(rootDir, cfg); err != nil {
		return fmt.Errorf("append chart version: %w", err)
	}

	// Step 7: Conditionally scaffold app.cue.
	if err := scaffoldAppCue(rootDir, cfg, images); err != nil {
		return fmt.Errorf("scaffold app.cue: %w", err)
	}

	// Step 8: Write brick entry on first stamp only. Re-stamps would
	// otherwise overwrite an operator-curated desc with the default
	// (cfg.Name) and flip stamp_type back to "helm-app". The brick
	// metadata is independent of chart upgrades; leave it alone once set.
	// New helm-apps land in the library tenant by default; defn-specific
	// apps (AWS-coupled ones) are moved manually later. TODO: --tenant flag.
	brickShard := filepath.Join(rootDir, "tenant", "library", "catalog", "brick-app--"+cfg.Name+".cue")
	if _, err := os.Stat(brickShard); os.IsNotExist(err) {
		if err := StampBrick(rootDir, "helm-app", "tenant/library/app/"+cfg.Name, cfg.Desc); err != nil {
			return fmt.Errorf("stamp brick: %w", err)
		}
	} else {
		fmt.Printf("  brick %s already present, skipping stamp-brick\n", filepath.Base(brickShard))
	}

	// Step 9 (formerly seeding) removed: AIDR-00146 evicts the kustomize
	// render to var/app/<name>/, and the var-render macros glob gen-app.cue
	// (allow_empty), so a freshly-stamped app's first `mise run hatch`
	// bootstraps the render from app.cue + chart with no placeholder needed
	// (the same zero-to-rendered path check-fork exercises). The old seeder
	// wrote source-dir placeholders with stale k8s-1-33/34/35 names -- now
	// pure orphans -- so it is gone, not redirected.

	// Step 10: Kustomize-only bricks (no kustomization.yaml) don't render
	// the chart -- the tarball is needed only for sha256/image discovery
	// and is not Bazel-tracked. Leaving it on disk trips check-bazel
	// ("git files not in Bazel"). Delete after the stamp completes.
	// AIDR-00146: a real kustomize app's kustomization.yaml now lives in
	// var/app/<name>/ (a prior gen put it there), so probe there.
	kustPath := filepath.Join(rootDir, "var", "app", cfg.Name, "kustomization.yaml")
	if _, err := os.Stat(kustPath); os.IsNotExist(err) {
		if rmErr := os.Remove(tgzPath); rmErr == nil {
			fmt.Printf("  removed unused tarball %s (kustomize-only app)\n", filepath.Base(tgzPath))
		}
	}

	fmt.Printf("stamped helm-app %s\n", cfg.Name)
	fmt.Printf("next steps:\n")
	fmt.Printf("  1. Edit tenant/library/app/%s/app.cue (helm_values, overlays, routes)\n", cfg.Name)
	fmt.Printf("  2. mise run gen\n")
	fmt.Printf("  3. mise run check -- --ignore-unclean-workarea\n")
	return nil
}

// sh runs a command and returns trimmed stdout.
func sh(dir string, args ...string) (string, error) {
	return runner.Output(context.Background(), runner.Opts{
		Args: args,
		Dir:  dir,
	})
}

// vendorChart pulls the helm chart and computes its SHA256.
func vendorChart(rootDir, appDir string, cfg HelmAppConfig) (string, string, error) {
	// Remove any pre-existing tarballs in the brick directory. We don't
	// glob by chart name because some charts ship a tarball whose
	// filename differs from cfg.ChartName (e.g. coder publishes
	// "coder_helm_<ver>.tgz" not "coder-<ver>.tgz"). Each helm-app brick
	// directory holds exactly one chart tarball; clearing the slate
	// before pull avoids stale-tarball collisions in BUILD.bazel
	// generation, which picks whichever .tgz sorts first.
	entries, _ := filepath.Glob(filepath.Join(appDir, "*.tgz"))
	for _, e := range entries {
		os.Remove(e)
	}

	// Pull chart.
	var args []string
	if strings.HasPrefix(cfg.ChartRepo, "oci://") {
		args = []string{"helm", "pull", cfg.ChartRepo + "/" + cfg.ChartName,
			"--version", cfg.ChartVersion, "-d", appDir}
	} else {
		args = []string{"helm", "pull", cfg.ChartName,
			"--repo", cfg.ChartRepo, "--version", cfg.ChartVersion, "-d", appDir}
	}

	if _, err := sh(rootDir, args...); err != nil {
		return "", "", fmt.Errorf("helm pull: %w", err)
	}

	// Find the downloaded tgz.
	tgzPattern := filepath.Join(appDir, cfg.ChartName+"-"+cfg.ChartVersion+".tgz")
	matches, _ := filepath.Glob(tgzPattern)
	if len(matches) == 0 {
		// Try without version in name (some charts name differently).
		matches, _ = filepath.Glob(filepath.Join(appDir, "*.tgz"))
	}
	if len(matches) == 0 {
		return "", "", fmt.Errorf("no .tgz found after helm pull")
	}
	tgzPath := matches[0]

	// Compute SHA256.
	f, err := os.Open(tgzPath)
	if err != nil {
		return "", "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", "", err
	}
	sha := hex.EncodeToString(h.Sum(nil))

	return tgzPath, sha, nil
}

// extractAppVersion reads appVersion from Chart.yaml inside a tarball.
func extractAppVersion(tgzPath string) (string, error) {
	f, err := os.Open(tgzPath)
	if err != nil {
		return "", err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return "", err
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", err
		}
		if strings.HasSuffix(hdr.Name, "/Chart.yaml") || hdr.Name == "Chart.yaml" {
			data, err := io.ReadAll(tr)
			if err != nil {
				return "", err
			}
			re := regexp.MustCompile(`(?m)^appVersion:\s*"?([^"\s]+)"?`)
			m := re.FindSubmatch(data)
			if m != nil {
				return string(m[1]), nil
			}
			return "", fmt.Errorf("appVersion not found in Chart.yaml")
		}
	}
	return "", fmt.Errorf("Chart.yaml not found in tarball")
}

// imageRef is a parsed container image reference.
type imageRef struct {
	Source string // e.g. "temporalio/server"
	Tag    string // e.g. "1.30.2"
}

func (r imageRef) Key() string { return r.Source + ":" + r.Tag }

// discoverImages runs helm template and extracts image references.
// Falls back to parsing values.yaml from the tarball if helm template fails
// (some charts require config values to render).
func discoverImages(rootDir, name, tgzPath string) ([]imageRef, error) {
	out, err := sh(rootDir, "helm", "template", name, tgzPath)
	if err != nil {
		fmt.Printf("  helm template failed, falling back to values.yaml parsing\n")
		return discoverImagesFromValues(tgzPath)
	}

	// Match image: lines in rendered YAML.
	re := regexp.MustCompile(`image:\s*"?([^"\s]+)"?`)
	seen := map[string]bool{}
	var images []imageRef

	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		matches := re.FindStringSubmatch(line)
		if matches == nil {
			continue
		}
		ref := matches[1]
		// Skip test images, busybox, etc.
		if strings.Contains(ref, "busybox") {
			continue
		}
		// Parse image:tag.
		source, tag := parseImageRef(ref)
		if source == "" || tag == "" {
			continue
		}
		key := source + ":" + tag
		if seen[key] {
			continue
		}
		seen[key] = true
		images = append(images, imageRef{Source: source, Tag: tag})
	}
	sort.Slice(images, func(i, j int) bool { return images[i].Key() < images[j].Key() })
	return images, nil
}

// parseImageRef splits "repo/image:tag" into source and tag.
func parseImageRef(ref string) (string, string) {
	// Handle digest-only refs.
	if strings.Contains(ref, "@sha256:") {
		return "", ""
	}
	parts := strings.SplitN(ref, ":", 2)
	source := parts[0]
	tag := "latest"
	if len(parts) > 1 {
		tag = parts[1]
	}
	// Skip refs without a real tag.
	if tag == "latest" {
		return "", ""
	}
	return source, tag
}

// discoverImagesFromValues extracts image repository+tag pairs from values.yaml
// inside a chart tarball. This is the fallback when helm template fails.
func discoverImagesFromValues(tgzPath string) ([]imageRef, error) {
	f, err := os.Open(tgzPath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	gz, err := gzip.NewReader(f)
	if err != nil {
		return nil, err
	}
	defer gz.Close()

	tr := tar.NewReader(gz)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if strings.HasSuffix(hdr.Name, "/values.yaml") || hdr.Name == "values.yaml" {
			data, err := io.ReadAll(tr)
			if err != nil {
				return nil, err
			}
			return parseValuesForImages(string(data)), nil
		}
	}
	return nil, fmt.Errorf("values.yaml not found in tarball")
}

// parseValuesForImages extracts image references from values.yaml content.
// Looks for repository:/tag: pairs that appear near each other.
func parseValuesForImages(content string) []imageRef {
	reRepo := regexp.MustCompile(`(?m)^\s+repository:\s*"?([^"\s]+)"?`)
	reTag := regexp.MustCompile(`(?m)^\s+tag:\s*"?([^"\s]+)"?`)

	lines := strings.Split(content, "\n")
	seen := map[string]bool{}
	var images []imageRef

	for i, line := range lines {
		repoMatch := reRepo.FindStringSubmatch(line)
		if repoMatch == nil {
			continue
		}
		repo := repoMatch[1]
		// Look for a tag: line within the next 5 lines.
		tag := ""
		for j := i + 1; j < len(lines) && j <= i+5; j++ {
			tagMatch := reTag.FindStringSubmatch(lines[j])
			if tagMatch != nil {
				tag = tagMatch[1]
				break
			}
		}
		if tag == "" || tag == "latest" {
			continue
		}
		// Skip commented-out or example repos.
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "#") {
			continue
		}
		key := repo + ":" + tag
		if seen[key] {
			continue
		}
		seen[key] = true
		images = append(images, imageRef{Source: repo, Tag: tag})
	}
	sort.Slice(images, func(i, j int) bool { return images[i].Key() < images[j].Key() })
	return images
}

// appendMirrors resolves digests and adds entries to catalog/mirrors.cue.
func appendMirrors(rootDir string, images []imageRef) error {
	text, err := ReadFile(rootDir, "kernel/catalog/mirrors.cue")
	if err != nil {
		return err
	}

	var added int
	for _, img := range images {
		key := fmt.Sprintf("%q", img.Key())
		if EntryExists(text, key) {
			fmt.Printf("  mirror %s: already present\n", img.Key())
			continue
		}

		// Resolve digest via crane.
		digest, err := sh(rootDir, "crane", "digest", img.Key())
		if err != nil {
			return fmt.Errorf("crane digest %s: %w", img.Key(), err)
		}

		entry := fmt.Sprintf("\n\t%s: {\n\t\tsource: %q\n\t\ttag:    %q\n\t\tdigest: %q\n\t}\n",
			key, img.Source, img.Tag, digest)

		var ok bool
		text, ok = InsertBeforeLastBrace(text, entry)
		if !ok {
			return fmt.Errorf("cannot find closing brace in mirrors.cue")
		}
		added++
		fmt.Printf("  mirror %s: added (digest: %s...)\n", img.Key(), digest[:19])
	}

	if added > 0 {
		if err := UpdateFile(rootDir, "kernel/catalog/mirrors.cue", text); err != nil {
			return err
		}
		// Insertion via raw text appends can leave double-blank lines or
		// trailing whitespace that cue fmt rejects. Run cue fmt to
		// normalize before the next hatch sync sees the file.
		if _, err := sh(rootDir, "cue", "fmt", "kernel/catalog/mirrors.cue"); err != nil {
			return fmt.Errorf("cue fmt mirrors.cue: %w", err)
		}
		fmt.Printf("  updated kernel/catalog/mirrors.cue (%d new entries)\n", added)
	}
	return nil
}

// appendVersion adds (or updates, on re-stamp) a #ToolVersion entry in
// kernel/schema/versions.cue. On re-stamp the chart_version + chart_sha256
// fields are rewritten; appVersion is also updated so the tool's binary
// pin tracks the chart upgrade.
func appendVersion(rootDir string, cfg HelmAppConfig, sha, appVersion string) error {
	text, err := ReadFile(rootDir, "kernel/schema/versions.cue")
	if err != nil {
		return err
	}

	cueKey := CueIdent(cfg.Name)

	if EntryExists(text, "\t"+cueKey+": #ToolVersion") {
		updated, changed, err := updateVersionEntry(text, cueKey, cfg.ChartVersion, sha)
		if err != nil {
			return err
		}
		if !changed {
			fmt.Printf("  versions.cue: %s already at chart_version %s\n", cueKey, cfg.ChartVersion)
			return nil
		}
		fmt.Printf("  versions.cue: bumped %s -> chart_version %s\n", cueKey, cfg.ChartVersion)
		return UpdateFile(rootDir, "kernel/schema/versions.cue", updated)
	}

	entry := fmt.Sprintf("\n\t%s: #ToolVersion & {\n\t\tversion:       %q\n\t\tchart_version: %q\n\t\tchart_sha256:  %q\n\t\tchart_url:     \"https://artifacthub.io/api/v1/packages/helm/%s/%s\"\n\t\tsync: []\n\t}\n",
		cueKey, appVersion, cfg.ChartVersion, sha, cfg.Name, cfg.ChartName)

	markers := []string{
		"\n\t// =========================================================================\n\t// Services",
		"\n\t// =========================================================================\n\t// Security",
		"\n\t// =========================================================================\n\t// Interactive",
		"\n\t// =========================================================================\n\t// AI tools",
		"\n\t// =========================================================================\n\t// Bazel modules",
	}

	text, ok := InsertBeforeMarker(text, entry, markers)
	if !ok {
		return fmt.Errorf("cannot find insertion point in versions.cue")
	}

	fmt.Printf("  updated schema/versions.cue: added %s\n", cueKey)
	return UpdateFile(rootDir, "kernel/schema/versions.cue", text)
}

// updateVersionEntry rewrites chart_version and chart_sha256 inside the
// cueKey block of versions.cue. The `version:` field tracks the binary
// release line and is operator-managed -- intentionally not bumped on
// re-stamp. Returns (text, changed, err).
func updateVersionEntry(text, cueKey, chartVersion, chartSha256 string) (string, bool, error) {
	header := "\t" + cueKey + ": #ToolVersion"
	start := strings.Index(text, header)
	if start < 0 {
		return text, false, fmt.Errorf("entry %s not found", cueKey)
	}
	openBrace := strings.Index(text[start:], "{")
	if openBrace < 0 {
		return text, false, fmt.Errorf("opening brace for %s not found", cueKey)
	}
	openBrace += start
	depth := 1
	end := openBrace + 1
	for end < len(text) && depth > 0 {
		switch text[end] {
		case '{':
			depth++
		case '}':
			depth--
		}
		end++
	}
	if depth != 0 {
		return text, false, fmt.Errorf("unbalanced braces in %s", cueKey)
	}
	block := text[openBrace:end]
	original := block

	bumpField := func(b, name, val string) string {
		re := regexp.MustCompile(`(?m)^(\s+` + regexp.QuoteMeta(name) + `:\s+)"[^"]*"`)
		return re.ReplaceAllString(b, "${1}"+fmt.Sprintf("%q", val))
	}
	block = bumpField(block, "chart_version", chartVersion)
	block = bumpField(block, "chart_sha256", chartSha256)

	if block == original {
		return text, false, nil
	}
	return text[:openBrace] + block + text[end:], true, nil
}

// appendApp creates the per-app catalog shard at
// tenant/library/catalog/apps-<name>.cue (per AIDR-00083 leaves-into-branches).
// Idempotent: skips if the shard already exists. Upgrades flow through
// schema.versions.<cueKey>.chart_version, so the shard never needs an edit.
func appendApp(rootDir string, cfg HelmAppConfig) error {
	relShard := filepath.Join("tenant", "library", "catalog", "apps-"+cfg.Name+".cue")
	shardPath := filepath.Join(rootDir, relShard)
	if _, err := os.Stat(shardPath); err == nil {
		fmt.Printf("  %s already present, skipping\n", relShard)
		return nil
	}

	cueKey := CueIdent(cfg.Name)
	appKey := CueKey(cfg.Name)

	body := fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: %s (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

import "github.com/defn/other/kernel/schema"

apps: %s: {
	name:          %q
	kind:          "kustomize"
	path:          "tenant/library/app/%s"
	chart_name:    %q
	chart_repo:    %q
	chart_version: schema.versions.%s.chart_version
	chart_sha256:  schema.versions.%s.chart_sha256
	desc:          %q
}
`, cfg.Name, appKey, cfg.Name, cfg.Name, cfg.ChartName, cfg.ChartRepo, cueKey, cueKey, cfg.Desc)

	if err := os.WriteFile(shardPath, []byte(body), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", relShard, err)
	}
	fmt.Printf("  created %s\n", relShard)
	return nil
}

// appendChartVersion handles the per-tenant chart_versions table. Post
// AIDR-00072 the table is sharded by owning cluster's tenant
// (tenant/<tenant>/catalog/chart_versions.cue). For upgrades, entries
// already exist in every relevant tenant -- this is a no-op. For new
// apps, the operator must manually seed cluster_digests entries in the
// tenants that should run the new chart; this function surfaces a TODO.
func appendChartVersion(rootDir string, cfg HelmAppConfig) error {
	appKey := CueKey(cfg.Name)
	probe := appKey + ": cluster_digests"

	tenantDir := filepath.Join(rootDir, "tenant")
	entries, err := os.ReadDir(tenantDir)
	if err != nil {
		return fmt.Errorf("read tenant dir: %w", err)
	}

	var found []string
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		path := filepath.Join("tenant", e.Name(), "catalog", "chart_versions.cue")
		text, err := ReadFile(rootDir, path)
		if err != nil {
			continue
		}
		if strings.Contains(text, probe) {
			found = append(found, e.Name())
		}
	}

	if len(found) > 0 {
		fmt.Printf("  chart_versions: %s already seeded in tenant(s): %s\n",
			cfg.Name, strings.Join(found, ", "))
		return nil
	}

	fmt.Printf("  TODO: seed cluster_digests for %q in the tenant(s) that\n", cfg.Name)
	fmt.Printf("        should run this chart -- e.g. add to\n")
	fmt.Printf("        tenant/<tenant>/catalog/chart_versions.cue:\n")
	fmt.Printf("            %q: cluster_digests: {\n", cfg.Name)
	fmt.Printf("                \"<cluster>\": version: \"0.0.1\"\n")
	fmt.Printf("            }\n")
	return nil
}

// scaffoldAppCue creates tenant/library/app/<name>/app.cue only if it
// doesn't exist. Re-stamps preserve any operator edits.
func scaffoldAppCue(rootDir string, cfg HelmAppConfig, images []imageRef) error {
	appCue := filepath.Join(rootDir, "tenant", "library", "app", cfg.Name, "app.cue")
	if _, err := os.Stat(appCue); err == nil {
		fmt.Printf("  tenant/library/app/%s/app.cue: already exists, skipping scaffold\n", cfg.Name)
		return nil
	}

	// Build images list.
	var imgParts []string
	for _, img := range images {
		imgParts = append(imgParts, fmt.Sprintf("%q", img.Source))
	}
	imgList := strings.Join(imgParts, ", ")

	var sb strings.Builder
	sb.WriteString("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\npackage app\n\n")
	sb.WriteString(fmt.Sprintf("images: [%s]\n\n", imgList))
	sb.WriteString("helm_values: {}\n")

	// Every app renders per-cluster -- include the per-cluster scaffold by
	// default. Remove what you don't need (route_mappings, etc.) when wiring up.
	sb.WriteString(`
// Per-cluster tags.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// Generate IngressRoutes from route_mappings.
objects: IngressRoute: {
	for routeName, route in route_mappings {
		(routeName): {
			apiVersion: "traefik.io/v1alpha1"
			kind:       "IngressRoute"
			metadata: {
				name:      routeName
				namespace: route.namespace
			}
			spec: {
				entryPoints: ["websecure"]
				routes: [{
					match: "Host(` + "`" + `\(route.host).\(_cluster_domain)` + "`" + `)"
					kind:  "Rule"
					if route.auth {
						middlewares: [{
							name:      "auth"
							namespace: "oauth2-proxy"
						}]
					}
					if route.service_kind != _|_ {
						services: [{
							name: route.service
							kind: route.service_kind
						}]
					}
					if route.service_kind == _|_ {
						services: [{
							name: route.service
							port: route.port
						}]
					}
				}]
				tls: secretName: "wildcard-tls"
			}
		}
	}
}

// Ingress routes served by Traefik.
route_mappings: [string]: {
	namespace:     string
	host:          string
	service:       string
	port:          *80 | number
	auth:          *true | bool
	service_kind?: string
}
`)

	if err := os.WriteFile(appCue, []byte(sb.String()), 0o644); err != nil {
		return err
	}
	fmt.Printf("  scaffolded app/%s/app.cue\n", cfg.Name)
	return nil
}
