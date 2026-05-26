// Package gen provides shared utilities for code generators.
//
// Context loads the CUE catalog and schema once, then generators
// query values and stamp templates without subprocess overhead.
//
// Thread safety: CatalogQuery and SchemaQuery are read-only on values
// built during NewContext. StampFromCUE and LoadCUEPackage create a
// fresh cue.Context per call, making them safe for concurrent use.
package gen

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
	"go.uber.org/zap"
)

// DefaultBrickSlug returns the default brick slug for a given brick
// path. Strips a leading "tenant/<name>/" or "kernel/" prefix so the
// resulting filename is stable across tenant/kernel moves; replaces
// remaining "/" with "--" to match the historical brick-*.cue
// convention. Mirrored in CUE inside kernel/spec/contracts-schema.cue
// so contract derivations agree with stamp.go's filename writes.
func DefaultBrickSlug(path string) string {
	parts := strings.Split(path, "/")
	switch {
	case len(parts) >= 3 && parts[0] == "tenant":
		parts = parts[2:]
	case len(parts) >= 2 && parts[0] == "kernel":
		parts = parts[1:]
	}
	return strings.Join(parts, "--")
}

// BrickSlug returns the explicit slug if set, otherwise the default
// derived from the brick path.
func BrickSlug(slug, path string) string {
	if slug != "" {
		return slug
	}
	return DefaultBrickSlug(path)
}

// Context holds shared state for all generators.
type Context struct {
	CUECtx       *cue.Context // used only during NewContext; not used concurrently
	Catalog      cue.Value    // read-only after construction
	Schema       cue.Value    // read-only after construction
	WorkDir      string
	Logger       *zap.Logger
	Quiet        bool
	SpecTree     interface{} // in-memory file tree from speclattice (avoids CUE re-eval)
	GitFileCount int         // number of git-tracked files (set by speclattice)

	// overlay maps absolute virtual paths under kernel/catalog/ and
	// kernel/spec/ to tenant-contributed file contents. Any CUE import
	// of github.com/defn/other/kernel/{catalog,spec} sees the merged set
	// as a single package. Catalog entries come from tenant/<t>/catalog/*.cue
	// (AIDR-00071); spec entries come from tenant/<t>/spec/*.cue (AIDR-00138
	// D5.2 tenant-spec overlay). Built at NewContext time; passed to
	// every load.Config.Overlay.
	overlay map[string]load.Source
}

// NewContext loads the CUE catalog and schema from workDir.
func NewContext(workDir string, logger *zap.Logger) (*Context, error) {
	absDir, err := filepath.Abs(workDir)
	if err != nil {
		return nil, fmt.Errorf("resolve workdir: %w", err)
	}

	ctx := cuecontext.New()

	overlay, err := buildOverlay(absDir)
	if err != nil {
		return nil, fmt.Errorf("build overlay: %w", err)
	}

	catalog, err := loadCUEPackageWithOverlay(ctx, absDir, "./kernel/catalog", nil, overlay)
	if err != nil {
		return nil, fmt.Errorf("load catalog: %w", err)
	}

	schema, err := loadCUEPackage(ctx, absDir, "./kernel/schema", nil)
	if err != nil {
		return nil, fmt.Errorf("load schema: %w", err)
	}

	return &Context{
		CUECtx:  ctx,
		Catalog: catalog,
		Schema:  schema,
		WorkDir: absDir,
		Logger:  logger,
		overlay: overlay,
	}, nil
}

// CatalogQuery looks up a top-level field in the catalog.
// The returned cue.Value is from the init-time context and must NOT be
// used concurrently with StampFromCUE or LoadCUEPackage. Extract data
// into Go types before starting goroutines.
func (c *Context) CatalogQuery(expr string) cue.Value {
	return c.Catalog.LookupPath(cue.ParsePath(expr))
}

// SchemaQuery looks up a top-level field in the schema.
func (c *Context) SchemaQuery(expr string) cue.Value {
	return c.Schema.LookupPath(cue.ParsePath(expr))
}

// DefaultTenant returns the catalog's default_tenant value -- the
// single configurable knob a kernel fork edits to swap in their own
// tenant name. Generators stamping instances whose tenant ownership
// isn't already encoded in a brick's path read this. Defaults to
// "defn" via the schema constraint; reading misconfigured catalogs
// (missing or non-string default_tenant) returns "defn" rather than
// panicking. See AIDR-00071.
func (c *Context) DefaultTenant() string {
	v := c.CatalogQuery("default_tenant")
	if !v.Exists() {
		return "defn"
	}
	s, err := v.String()
	if err != nil || s == "" {
		return "defn"
	}
	return s
}

// MirrorPrefix returns the catalog's mirror_prefix value -- the
// per-tenant registry-mirror prefix that `defn hatch helm-upgrade`
// strips from image refs before comparing pre-/post-upgrade image
// sets. Empty string means "no mirror" and callers should treat the
// strip as a no-op. Schema defaults to "" so forks without a mirror
// need no opt-out. See AIDR-00142.
func (c *Context) MirrorPrefix() string {
	v := c.CatalogQuery("mirror_prefix")
	if !v.Exists() {
		return ""
	}
	s, err := v.String()
	if err != nil {
		return ""
	}
	return s
}

// StampFile describes one output file from a CUE template.
type StampFile struct {
	Field    string // CUE expression to evaluate (e.g., "build_bazel")
	Filename string // output filename (e.g., "BUILD.bazel")
}

// StampFromCUE evaluates a CUE template with tags and writes output files.
// Thread-safe: creates a fresh cue.Context per call.
func (c *Context) StampFromCUE(templatePath, dirPath string, tags map[string]string, files []StampFile) error {
	if err := os.MkdirAll(filepath.Join(c.WorkDir, dirPath), 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", dirPath, err)
	}

	tagList := make([]string, 0, len(tags))
	for k, v := range tags {
		tagList = append(tagList, k+"="+v)
	}

	// Fresh CUE context for thread safety
	freshCtx := cuecontext.New()
	val, err := loadCUEPackageWithOverlay(freshCtx, c.WorkDir, templatePath, tagList, c.overlay)
	if err != nil {
		return fmt.Errorf("load template %s: %w", templatePath, err)
	}

	for _, f := range files {
		content, err := val.LookupPath(cue.ParsePath(f.Field)).String()
		if err != nil {
			return fmt.Errorf("eval %s.%s: %w", templatePath, f.Field, err)
		}
		outPath := filepath.Join(c.WorkDir, dirPath, f.Filename)
		if _, err := WriteIfChanged(outPath, []byte(content+"\n"), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", outPath, err)
		}
	}
	return nil
}

// StampContent evaluates a CUE template field and returns its string content.
func (c *Context) StampContent(templatePath string, tags map[string]string, field string) (string, error) {
	tagList := make([]string, 0, len(tags))
	for k, v := range tags {
		tagList = append(tagList, k+"="+v)
	}
	freshCtx := cuecontext.New()
	val, err := loadCUEPackageWithOverlay(freshCtx, c.WorkDir, templatePath, tagList, c.overlay)
	if err != nil {
		return "", fmt.Errorf("load template %s: %w", templatePath, err)
	}
	content, err := val.LookupPath(cue.ParsePath(field)).String()
	if err != nil {
		return "", fmt.Errorf("eval %s.%s: %w", templatePath, field, err)
	}
	return content, nil
}

// LoadCUEPackage loads a CUE package with optional tags.
// Thread-safe: creates a fresh cue.Context per call.
func (c *Context) LoadCUEPackage(pkg string, tags []string) (cue.Value, error) {
	freshCtx := cuecontext.New()
	return loadCUEPackageWithOverlay(freshCtx, c.WorkDir, pkg, tags, c.overlay)
}

// RefreshOverlay rebuilds the load overlay from the current on-disk
// state. The overlay is snapshotted at NewContext; generators that
// rewrite var/ outputs mid-pipeline (cuetree -> var/gen-manifest.cue,
// speclattice -> var/gen-lattice.cue) make that snapshot stale. Loads
// that must observe the freshly-generated content -- notably the
// manifest validation -- call this first so the var overlay re-projects
// current bytes rather than the NewContext snapshot (AIDR-00145 D5.1).
func (c *Context) RefreshOverlay() error {
	overlay, err := buildOverlay(c.WorkDir)
	if err != nil {
		return err
	}
	c.overlay = overlay
	return nil
}

// buildOverlay reads every tenant/<t>/{catalog,spec}/*.cue file and
// returns a load.Overlay map that virtually projects them into the
// matching kernel/{catalog,spec}/ directory. Filenames are uniqued
// with a tenant prefix to avoid colliding with kernel files. Any CUE
// import of github.com/defn/other/kernel/{catalog,spec} using this
// overlay sees the merged set as a single package.
//
// catalog overlays: AIDR-00071 kernel/tenant decoupling.
// spec overlays:    AIDR-00138 D5.2 tenant-spec extensions (manual-files
//
//	shards for tenant-owned hand-written files).
//
// var overlays:     AIDR-00145 D5.1 -- workspace-derived generator
//
//	outputs (gen-manifest.cue, gen-lattice.cue, gen-chart-digests.cue)
//	physically live in the top-level var/ dir (a peer to kernel/ and
//	tenant/) so kernel/ and tenant/ change only on structural edits,
//	never to track regen churn. var/ is not bundled by bootstrap; a
//	fork grows its own. Each var/*.cue logically belongs to a declared
//	CUE package and is re-projected to kernel/<package>/<basename> so
//	it unifies as a member of that package at load time. The convention
//	is that a var-file's package name equals its logical kernel dir
//	(manifest/spec/catalog today).
func buildOverlay(absDir string) (map[string]load.Source, error) {
	overlay := map[string]load.Source{}
	tenantsDir := filepath.Join(absDir, "tenant")
	tenants, err := os.ReadDir(tenantsDir)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	for _, t := range tenants {
		if !t.IsDir() {
			continue
		}
		for _, sub := range []string{"catalog", "spec"} {
			subDir := filepath.Join(tenantsDir, t.Name(), sub)
			entries, err := os.ReadDir(subDir)
			if err != nil {
				continue
			}
			for _, e := range entries {
				if e.IsDir() || !strings.HasSuffix(e.Name(), ".cue") {
					continue
				}
				src, err := os.ReadFile(filepath.Join(subDir, e.Name()))
				if err != nil {
					return nil, err
				}
				virt := filepath.Join(absDir, "kernel", sub,
					"tenant--"+t.Name()+"--"+e.Name())
				overlay[virt] = load.FromBytes(src)
			}
		}
	}
	if err := addVarOverlay(absDir, overlay); err != nil {
		return nil, err
	}
	return overlay, nil
}

// addVarOverlay re-projects every kernel/var/*.cue back into the kernel
// directory matching its declared CUE package, so the file unifies as a
// member of that package while physically residing under kernel/var/
// (AIDR-00145 D5.1).
func addVarOverlay(absDir string, overlay map[string]load.Source) error {
	varDir := filepath.Join(absDir, "var")
	entries, err := os.ReadDir(varDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".cue") {
			continue
		}
		src, err := os.ReadFile(filepath.Join(varDir, e.Name()))
		if err != nil {
			return err
		}
		pkg := cuePackageName(src)
		if pkg == "" {
			return fmt.Errorf("kernel/var/%s: no package declaration", e.Name())
		}
		virt := filepath.Join(absDir, "kernel", pkg, e.Name())
		overlay[virt] = load.FromBytes(src)
	}
	return nil
}

// cuePackageName returns the package name declared in a CUE source, or
// "" if none is found. Skips blank lines, // line comments, and @attr
// lines (e.g. @experiment(...)) that legally precede the declaration.
func cuePackageName(src []byte) string {
	for _, line := range strings.Split(string(src), "\n") {
		t := strings.TrimSpace(line)
		if t == "" || strings.HasPrefix(t, "//") || strings.HasPrefix(t, "@") {
			continue
		}
		if rest, ok := strings.CutPrefix(t, "package "); ok {
			return strings.TrimSpace(rest)
		}
		// First non-trivial line that isn't `package ...` means the
		// file has no package clause (or it's malformed); stop.
		return ""
	}
	return ""
}

func loadCUEPackage(ctx *cue.Context, dir, pkg string, tags []string) (cue.Value, error) {
	return loadCUEPackageWithOverlay(ctx, dir, pkg, tags, nil)
}

func loadCUEPackageWithOverlay(ctx *cue.Context, dir, pkg string, tags []string, overlay map[string]load.Source) (cue.Value, error) {
	cfg := &load.Config{
		Dir:     dir,
		Tags:    tags,
		Overlay: overlay,
	}
	insts := load.Instances([]string{pkg}, cfg)
	if len(insts) == 0 {
		return cue.Value{}, fmt.Errorf("no instances for %s", pkg)
	}
	if insts[0].Err != nil {
		return cue.Value{}, fmt.Errorf("load %s: %w", pkg, insts[0].Err)
	}
	val := ctx.BuildInstance(insts[0])
	if val.Err() != nil {
		return cue.Value{}, fmt.Errorf("build %s: %w", pkg, val.Err())
	}
	return val, nil
}

// WriteIfChanged writes content to path only if it differs from existing content.
// Preserves mtime when unchanged, which is critical for Bazel's analysis cache.
func WriteIfChanged(path string, content []byte, perm os.FileMode) (changed bool, err error) {
	if existing, err := os.ReadFile(path); err == nil && string(existing) == string(content) {
		return false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err
	}
	return true, os.WriteFile(path, content, perm)
}

// Parallel runs fns concurrently and returns the first error (if any).
func Parallel(fns ...func() error) error {
	errs := make([]error, len(fns))
	var wg sync.WaitGroup
	wg.Add(len(fns))
	for i, fn := range fns {
		go func(idx int, f func() error) {
			defer wg.Done()
			errs[idx] = f()
		}(i, fn)
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			return err
		}
	}
	return nil
}

// ParallelN runs up to n work items concurrently using a worker pool.
func ParallelN(n int, items int, fn func(i int) error) error {
	if items == 0 {
		return nil
	}
	if n <= 0 || n > items {
		n = items
	}

	errs := make([]error, items)
	work := make(chan int, items)
	var wg sync.WaitGroup

	for w := 0; w < n; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range work {
				errs[i] = fn(i)
			}
		}()
	}

	for i := 0; i < items; i++ {
		work <- i
	}
	close(work)
	wg.Wait()

	for _, err := range errs {
		if err != nil {
			return err
		}
	}
	return nil
}

// IterMap iterates over a CUE struct value and calls fn for each field.
func IterMap(v cue.Value, fn func(key string, val cue.Value) error) error {
	iter, err := v.Fields(cue.Optional(true))
	if err != nil {
		return err
	}
	for iter.Next() {
		if err := fn(iter.Selector().String(), iter.Value()); err != nil {
			return err
		}
	}
	return nil
}

// IterList iterates over a CUE list value and calls fn for each element.
func IterList(v cue.Value, fn func(val cue.Value) error) error {
	iter, err := v.List()
	if err != nil {
		return err
	}
	for iter.Next() {
		if err := fn(iter.Value()); err != nil {
			return err
		}
	}
	return nil
}

// DecodeString extracts a string from a CUE value at the given path.
func DecodeString(v cue.Value, path string) (string, error) {
	return v.LookupPath(cue.ParsePath(path)).String()
}

// DecodeStringOr extracts a string with a default if the path doesn't exist.
func DecodeStringOr(v cue.Value, path, fallback string) string {
	s, err := v.LookupPath(cue.ParsePath(path)).String()
	if err != nil {
		return fallback
	}
	return s
}

// DecodeBoolOr extracts a bool with a default if the path doesn't exist.
func DecodeBoolOr(v cue.Value, path string, fallback bool) bool {
	b, err := v.LookupPath(cue.ParsePath(path)).Bool()
	if err != nil {
		return fallback
	}
	return b
}

// CueFieldKey strips quotes from a CUE field selector string.
func CueFieldKey(s string) string {
	return strings.Trim(s, "\"")
}
