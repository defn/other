// Package stamp provides shared logic for stamping bricks into the catalog.
package stamp

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// InterfaceMap maps short type names to interface paths.
var InterfaceMap = map[string]string{
	"go-lib":        "kernel/interface/go-lib",
	"go-cmd":        "kernel/interface/go-cmd",
	"go-cmd-cue":    "kernel/interface/go-cmd-cue",
	"go-cmd-parent": "kernel/interface/go-cmd-parent",
	"helm-app":      "kernel/interface/app",
	"skill":         "kernel/interface/skill",
	"slack-bot":     "kernel/interface/slack-bot",
	"discord-bot":   "kernel/interface/discord-bot",
	"gmail-bot":     "kernel/interface/gmail-bot",
	"matrix-bot":    "kernel/interface/matrix-bot",
	"telegram-bot":  "kernel/interface/telegram-bot",
}

// goStampTypes is the set of stamp types whose generators bake the
// brick's last path segment into a Go `package <name>` directive.
// That position requires a valid Go identifier ([a-z_][a-z0-9_]*),
// so hyphens, dots, and uppercase chars get canonicalized at stamp
// time -- users can type the kebab-case CLI verb they expect (e.g.
// `defn stamp gocmd go/cmd/cluster/sync-crds`) and the brick lands
// at a Go-valid path (`go/cmd/cluster/synccrds`). See
// canonicalGoSegment.
//
// go-lib is intentionally absent: its template (kernel/interface/
// go-lib/templates.cue) emits a Bazel target name (`go_library(name
// = "<name>")`, which permits hyphens) but no package directive.
// Existing vendored go-lib bricks like
// `v/buildkite--agent/internal/job/integration/test-binary-hook`
// rely on that tolerance.
var goStampTypes = map[string]bool{
	"go-cmd":        true,
	"go-cmd-cue":    true,
	"go-cmd-parent": true,
}

// canonicalGoSegment maps an input brick-name segment to a valid Go
// identifier following the project convention (concatenated lowercase
// without separators -- e.g. `awsconfig`, `gocmdparent`,
// `crosstenantlit`). Returns the canonical form and whether it
// differs from the input.
//
//   - hyphens, dots, and other non-identifier chars are stripped
//   - uppercase letters are lowercased
//   - leading digits are rejected (returns input unchanged + ok=false)
//   - empty result after stripping is rejected (returns input + ok=false)
//
// The boolean return distinguishes "no change needed" from "change
// applied"; callers print a notice in the change case so users see
// what happened.
func canonicalGoSegment(s string) (canonical string, changed bool, ok bool) {
	if s == "" {
		return s, false, false
	}
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z':
			b.WriteRune(r)
		case r >= 'A' && r <= 'Z':
			b.WriteRune(r + ('a' - 'A'))
		case r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '_':
			b.WriteRune(r)
		case r == '-' || r == '.':
			// drop; the project convention is concat (awsconfig, not aws_config)
		default:
			// any other rune is rejected -- can't safely canonicalize
			return s, false, false
		}
	}
	out := b.String()
	if out == "" {
		return s, false, false
	}
	if c := out[0]; c >= '0' && c <= '9' {
		return s, false, false
	}
	return out, out != s, true
}

// sortedKeys returns the keys of m in sorted order. Local helper for
// stable error messages.
func sortedKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j] < out[j-1]; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out
}

// renderStringList renders a Go []string as a CUE list literal.
// Empty slices render as `[]`; non-empty as `["a", "b", ...]`.
// Used by StampBrick to inline reads / writes lists in catalog
// brick files (AIDR-00136 -- gen-time mirror of worker IO).
func renderStringList(xs []string) string {
	if len(xs) == 0 {
		return "[]"
	}
	parts := make([]string, len(xs))
	for i, x := range xs {
		parts[i] = fmt.Sprintf("%q", x)
	}
	return "[" + strings.Join(parts, ", ") + "]"
}

// brickCatalogDir returns the workspace-relative catalog directory
// that owns a brick at the given path. tenant/<owner>/<rest> -> the
// owning tenant's catalog; everything else (kernel/, top-level) ->
// kernel/catalog. Used by StampBrick (see also restamp/contract.cue
// which mirrors this rule for path claims).
func brickCatalogDir(path string) string {
	parts := strings.Split(path, "/")
	if len(parts) >= 2 && parts[0] == "tenant" {
		return filepath.Join("tenant", parts[1], "catalog")
	}
	return filepath.Join("kernel", "catalog")
}

// BrickOption configures optional brick fields.
type BrickOption func(*brickConfig)

type brickConfig struct {
	parent string
	// reads / writes are AIDR-00136's gen-time mirror of the
	// brick's <path>/dispatch.cue worker.reads / worker.writes.
	// Set by `restamp` after reading the brick's dispatch.cue;
	// when unset, StampBrick emits empty `[]` lists.
	readsSet  bool
	reads     []string
	writesSet bool
	writes    []string
}

// WithParent sets the parent path for a child command brick.
func WithParent(parent string) BrickOption {
	return func(c *brickConfig) { c.parent = parent }
}

// WithIO sets the brick's reads and writes lists, both inlined as
// CUE list literals in the catalog file. AIDR-00136: the values
// mirror the brick's <path>/dispatch.cue worker -- restamp passes
// them through every hatch so the catalog tracks user edits to
// the worker.
func WithIO(reads, writes []string) BrickOption {
	return func(c *brickConfig) {
		c.readsSet = true
		c.writesSet = true
		c.reads = append([]string(nil), reads...)
		c.writes = append([]string(nil), writes...)
	}
}

// StampBrick creates or updates a brick entry in the catalog.
// All paths are resolved relative to rootDir.
// Each brick is stored as an individual file: catalog/brick-<path>.cue
func StampBrick(rootDir, typeName, path, desc string, opts ...BrickOption) error {
	if path == "" {
		return fmt.Errorf("path is required (e.g. defn stamp %s my/brick/path)", typeName)
	}

	if strings.HasPrefix(path, "/") || strings.HasPrefix(path, ".") {
		return fmt.Errorf("path must be relative (got %q)", path)
	}

	iface, ok := InterfaceMap[typeName]
	if !ok {
		var types []string
		for k := range InterfaceMap {
			types = append(types, k)
		}
		return fmt.Errorf("unknown stamp type %q (known: %s)", typeName, strings.Join(types, ", "))
	}

	// Canonicalize the last path segment for Go-related stamp types --
	// the segment becomes a Go package name + Bazel target, both of
	// which require valid Go identifiers. The project convention is
	// concatenated lowercase (awsconfig, not aws_config). When we
	// rewrite, surface the change so the user knows what happened and
	// can override the cobra verb if they need the kebab-case form
	// (set cmd.Use in RegisterFlags). See canonicalGoSegment.
	if goStampTypes[typeName] {
		parts := strings.Split(path, "/")
		last := parts[len(parts)-1]
		canonical, changed, ok := canonicalGoSegment(last)
		if !ok {
			return fmt.Errorf("brick name %q is not canonicalizable to a Go identifier (must contain at least one [a-zA-Z_] and not start with a digit). Stamp types %v require Go-valid package names", last, sortedKeys(goStampTypes))
		}
		if changed {
			parts[len(parts)-1] = canonical
			newPath := strings.Join(parts, "/")
			fmt.Printf("note: brick name %q canonicalized to %q (project convention: lowercase concat for Go package + Bazel target)\n", last, canonical)
			fmt.Printf("      brick path: %s -> %s\n", path, newPath)
			fmt.Printf("      override the user-facing CLI verb in RegisterFlags if you want the original form, e.g.:\n")
			fmt.Printf("          cmd.Use = %q\n", last)
			path = newPath
		}
	}

	if desc == "" {
		parts := strings.Split(path, "/")
		desc = parts[len(parts)-1]
	}

	// Apply options.
	cfg := &brickConfig{}
	for _, opt := range opts {
		opt(cfg)
	}

	// Auto-detect parent for go/cmd/* paths (including tenant/<x>/go/cmd/*)
	// with 4+ segments under the cmd dir.
	if cfg.parent == "" {
		parts := strings.Split(path, "/")
		switch {
		case len(parts) >= 4 && parts[0] == "go" && parts[1] == "cmd":
			cfg.parent = strings.Join(parts[:len(parts)-1], "/")
		case len(parts) >= 6 && parts[0] == "tenant" && parts[2] == "go" && parts[3] == "cmd":
			cfg.parent = strings.Join(parts[:len(parts)-1], "/")
		}
	}

	// Derive filename via the slug rule (gen.DefaultBrickSlug):
	// strips a leading tenant/<name>/ or kernel/ prefix so the
	// filename is stable across tenant moves. E.g.
	// "tenant/defn/bot/molly" -> "brick-bot--molly.cue".
	fname := "brick-" + gen.DefaultBrickSlug(path) + ".cue"

	// Output the brick file inside its owning tenant's catalog/ when
	// the brick path starts with tenant/<owner>/, else fall back to
	// kernel/catalog/. Keeps the kernel substrate free of tenant-
	// specific brick registrations -- a fork can drop in their own
	// tenant tree without inheriting any defn-pathed brick file.
	// See AIDR-00071 for the kernel/tenant decoupling.
	brickFile := filepath.Join(rootDir, brickCatalogDir(path), fname)

	// Build entry with optional fields.
	var optLines string
	if cfg.parent != "" {
		optLines += fmt.Sprintf("\t\tparent:     %q\n", cfg.parent)
	}
	optLines += fmt.Sprintf("\t\tstamp_type: %q\n", typeName)

	slug := gen.DefaultBrickSlug(path)

	// AIDR-00136: inline `reads:` / `writes:` mirror the brick's
	// dispatch.cue worker.reads / worker.writes when restamp has
	// passed them through WithIO. When unset (initial stamp before
	// any hatch, or a code path that doesn't care), default to
	// empty lists. Restamp re-runs StampBrick at every hatch, so
	// the catalog converges on whatever the worker declares.
	readsLit := "[]"
	writesLit := "[]"
	if cfg.readsSet {
		readsLit = renderStringList(cfg.reads)
	}
	if cfg.writesSet {
		writesLit = renderStringList(cfg.writes)
	}

	// `cue fmt` always emits list-valued fields with single-space
	// separator (`reads: [...]`) and only aligns string-valued
	// fields. Match that here so the emitted file passes its own
	// fmt_test without a follow-up rewrite.
	entry := fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"%s": {
		path:       "%s"
		slug:       "%s"
		kind:       "component"
		desc:       "%s"
		implements: "%s"
		reads: %s
		writes: %s
%s	}
}
`, path, path, slug, desc, iface, readsLit, writesLit, optLines)

	existing, err := os.ReadFile(brickFile)
	if err == nil && string(existing) == entry {
		fmt.Printf("no changes: %s already configured as %s\n", path, typeName)
		return nil
	}

	action := "created"
	if err == nil {
		action = "updated"
	}

	if err := os.MkdirAll(filepath.Dir(brickFile), 0o755); err != nil {
		return fmt.Errorf("mkdir catalog: %w", err)
	}

	if err := os.WriteFile(brickFile, []byte(entry), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", brickFile, err)
	}
	fmt.Printf("%s: %s (type: %s, desc: %q)\n", action, path, typeName, desc)

	if err := os.MkdirAll(filepath.Join(rootDir, path), 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", path, err)
	}

	return nil
}

// StampTenant scaffolds the universal-identity hand-written file
// set for a tenant: every standard subdir gets its required-by-schema
// hand-written files, even if the tenant is "empty" in that
// dimension. Producing the same shape across all tenants means we
// can compare them as sets (some equal, some empty) and the gen
// pipeline never needs conditionals on "does this tenant have
// infra/?" -- the infra/ dir always exists, the generator always
// writes into it, and an empty AWS catalog produces an empty
// (but coherent) infra tree.
//
// File set produced (workspace-relative under tenant/<name>/):
//
//	BUILD.bazel
//	app/BUILD.bazel
//	aws/BUILD.bazel
//	bot/BUILD.bazel + bot/.gitignore + bot/mise.toml
//	catalog/BUILD.bazel
//	env/BUILD.bazel
//	infra/mise.toml + infra/.mise/tasks/BUILD.bazel
//	k3d/BUILD.bazel
//	k8s/BUILD.bazel
//
// playbook/ is OPT-IN -- it requires real ansible inventory + a
// macos.yaml playbook, both with tenant-specific content. The
// stamp doesn't synthesize those.
//
// Stamp is create-if-missing: re-running on an existing tenant
// preserves any hand-edited file (BUILD.bazel docstrings carry
// tenant-specific prose). Use defn gen to refresh generator-
// managed files instead.
//
// See AIDR-00071 (kernel/tenant decoupling) for the surrounding
// design and //kernel/spec:tenant_stamp_smoke for the test that
// pins this set.
func StampTenant(rootDir, name string) error {
	if name == "" {
		return fmt.Errorf("name is required (e.g. defn stamp tenant my-tenant)")
	}
	if strings.ContainsAny(name, "/.\\ \t") {
		return fmt.Errorf("name must be a single path segment (got %q)", name)
	}

	tenantRoot := filepath.Join(rootDir, "tenant", name)

	stdBuildBazel := func(docstring string) string {
		return docstring + `

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = [
        "bazel",
        "bazel-build",
    ],
)
`
	}

	files := []struct {
		rel  string
		body string
	}{
		{
			"BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/ -- top-level container for the %s tenant's instance data.

Stamped by defn stamp tenant. Hand-edit this docstring to describe
what the tenant represents; the stamp won't overwrite it.
"""`, name, name)),
		},
		{
			"app/BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/app/ -- application bricks owned by this tenant.

Per-app subdirs are stamped via defn stamp helm-app (or hand-
authored for raw apps). Empty here is legal -- a tenant with no
apps just has this BUILD.bazel.
"""`, name)),
		},
		{
			"aws/BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/aws/ -- AWS configuration owned by this tenant.

The awsconfig generator writes root/.aws/config from
catalog.aws_orgs + aws_accounts; tenant/<x>/aws/ is the manifest
surface for tenant-owned hand-written AWS files (none today).
"""`, name)),
		},
		{
			"bot/BUILD.bazel",
			`"""Bot parent directory -- shared config inherited by bot instances."""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

exports_files([
    ".gitignore",
    "mise.toml",
])

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

fmt_test(
    name = "gitignore_fmt",
    src = ".gitignore",
    tool = "textfmt",
)

fmt_test(
    name = "mise_toml_fmt",
    src = "mise.toml",
    tool = "taplo",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = [
        "bazel",
        "bazel-build",
    ],
)

tagged_file(
    name = "gitignore_tag",
    src = ".gitignore",
    tags = [
        "config",
        "git",
    ],
)

tagged_file(
    name = "mise_toml_tag",
    src = "mise.toml",
    tags = [
        "config",
        "mise",
        "toml",
    ],
)
`,
		},
		{
			"bot/.gitignore",
			".env\n",
		},
		{
			"bot/mise.toml",
			`# Bot parent config -- credentials inherited by all bot subdirectories.
# Secrets loaded from .env (not checked in).
[env]
_.file = ".env"
`,
		},
		{
			"catalog/BUILD.bazel",
			`"""Per-tenant catalog instance data; merged into kernel catalog at load time."""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file", "tagged_package")

exports_files(glob(["*.cue"]))

# Used by //kernel/spec/test:fork_smoke (AIDR-00071).
filegroup(
    name = "catalog_files",
    srcs = glob(["*.cue"]),
    visibility = ["//kernel/spec:__pkg__"],
)

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = ["bazel-build"],
)

tagged_package(exclude = ["BUILD.bazel"])
`,
		},
		{
			"env/BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/env/ -- environment definitions owned by this tenant.

Empty here is legal; per-env subdirs (e.g. env/versions/) are
hand-authored when the tenant adopts environment tracking.
"""`, name)),
		},
		{
			// infra/BUILD.bazel: hand-written for tenants that aren't
			// the active default_tenant (no AWS infra). When a tenant
			// becomes default_tenant AND has AWS catalog data, the
			// infra generator overwrites this file with the AWS-aware
			// version (parent_build_bazel template). The two versions
			// are functionally compatible -- both register
			// fmt_test+tagged_file for mise.toml.
			"infra/BUILD.bazel",
			`load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = [
        "bazel",
        "bazel-build",
    ],
)

fmt_test(
    name = "mise_toml_fmt",
    src = "mise.toml",
    tool = "taplo",
)

tagged_file(
    name = "mise_toml_tag",
    src = "mise.toml",
    tags = [
        "config",
        "toml",
    ],
)
`,
		},
		{
			"infra/mise.toml",
			`[env]
TF_PLUGIN_CACHE_DIR = "{{env.HOME}}/.terraform.d/plugin-cache"
`,
		},
		{
			"infra/.mise/tasks/BUILD.bazel",
			stdBuildBazel(`"""Infrastructure mise tasks."""`),
		},
		{
			"k3d/BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/k3d/ -- k3d cluster instances owned by this tenant.

Per-cluster subdirs are generated by the k3d generator from
catalog.k3d_clusters entries. Empty here is legal; a tenant with
no clusters just has this BUILD.bazel.
"""`, name)),
		},
		{
			"k8s/BUILD.bazel",
			stdBuildBazel(fmt.Sprintf(`"""tenant/%s/k8s/ -- k8s platform definitions owned by this tenant.

Per-platform subdirs are stamped via the k8s generator from
catalog.k8s_platforms entries. Empty here is legal.
"""`, name)),
		},
	}

	for _, f := range files {
		path := filepath.Join(tenantRoot, f.rel)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return fmt.Errorf("mkdir %s: %w", filepath.Dir(f.rel), err)
		}
		if _, err := os.Stat(path); err == nil {
			fmt.Printf("preserved: tenant/%s/%s already exists\n", name, f.rel)
			continue
		}
		if err := os.WriteFile(path, []byte(f.body), 0o644); err != nil {
			return fmt.Errorf("write tenant/%s/%s: %w", name, f.rel, err)
		}
		fmt.Printf("created: tenant/%s/%s\n", name, f.rel)
	}

	return nil
}
