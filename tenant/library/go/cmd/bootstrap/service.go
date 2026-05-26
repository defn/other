// Package bootstrap implements `defn bootstrap` (AIDR-00138 D5
// step 5, AIDR-00139 Tier 1, AIDR-00140 carry-forward retirement
// of the babashka stand-in).
//
// It copies the bootstrap bundle (kernel/, tenant/library/, bin/,
// gen/, go/, workspace scaffolding, .devcontainer, .mise/tasks) from
// the current workspace into a target fork directory, rewrites the
// CUE + Go module names, stubs the fork's leaf tenant (catalog +
// spec + infra), regenerates `.bazelrc.workspace` so the fork's
// Bazel sandbox points at the fork's own mise.toml, and commits the
// result.
//
// Defaults match the babashka stand-in: target=other/m, CUE
// module=github.com/defn/other, Go module=github.com/defn/other/m.
//
// `init` and `verify` are implemented. `verify` reports source-SHA
// drift and, when SHA drifts, enumerates which bundled files have
// changed in source between the recorded SHA and host HEAD (the
// files whose changes would propagate to the fork on re-bootstrap).
// The full rewrite-equivalence classification (worktree + per-file
// diff + BOOTSTRAP.lock allow-list) is a follow-up tracked in
// AIDR-00140. `update` (re-apply against newer source SHA with
// merge surfacing) is also a follow-up.
package bootstrap

import (
	"bytes"
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/spf13/cobra"
)

// Config holds configuration for the bootstrap subcommand.
type Config struct {
	Target    string
	CueModule string
	GoModule  string
	Verify    bool
}

// Service implements ServiceRunner for the bootstrap subcommand.
type Service struct{}

// NewService creates a new bootstrap service.
func NewService() *Service { return &Service{} }

// Module defaults match the historical babashka stand-in (`mise run
// bootstrap-other`, retired in AIDR-00140): the probe fork is the
// "other" module. There is no default --target: per AIDR-00148/00149 a
// no-arg `defn bootstrap` lands in a fresh random temp dir OUTSIDE the
// source tree (see Run), never a subdir of m/ -- a nested fork inherits
// defn's mise/bazel/git config and gives false-positive portability. The
// canonical persistent fork now lives in the separate defn/other repo.
const (
	defaultCueModule = "github.com/defn/other"
	defaultGoModule  = "github.com/defn/other/m"
)

// modulePathRe constrains user-supplied CUE/Go module values to a
// safe ASCII path shape (lowercase identifiers separated by
// dots/slashes/hyphens/underscores). The interpolation sites --
// cliMainGo, authCUE, cliModulesGo, and rewriteModulePaths --
// splice the value into Go/CUE source text via string concat or
// strings.ReplaceAll, with no escaping; without this gate, a
// caller passing `--cue-module='x"; func init(){...}; var _="x'`
// would land arbitrary Go statements inside the fork's seed
// main.go / auth.cue / modules.go that subsequently compile into
// the namesake CLI binary. The verify path additionally re-reads
// these values from the target's cue.mod/module.cue + go.mod via
// permissive regexes and re-runs the stamp pipeline against them,
// so a previously-bootstrapped malicious target could re-inject on
// every verify call; the same regex therefore re-validates after
// the round-trip in verifyTarget. Per AIDR-00144 security review.
var modulePathRe = regexp.MustCompile(`^[a-z][a-z0-9./_-]*$`)

func validateModule(field, value string) error {
	if !modulePathRe.MatchString(value) {
		return fmt.Errorf("--%s value %q must match %s -- no quotes, backticks, parens, or whitespace (prevents code injection into the seed CLI binary; see AIDR-00144)", field, value, modulePathRe)
	}
	return nil
}

// bundleDirs are rsync'd from source to target with --delete.
// "v" (vendored deps) ride along so the fork can compile from source.
// Library cmds + lib packages ship via tenant/library. "root" carries
// hand-written substrate-level content (LICENSE, README, AGENTS.md,
// sp-* skills) until skills move under tenant/library/skills/. "go"
// was dropped in AIDR-00141 Stage 3.5d -- the fork's namesake CLI is
// stamped at boot under tenant/<fork>/go/cmd/<fork>/ by stampForkTenant.
var bundleDirs = []string{
	".devcontainer",
	"bin",
	"cue.mod",
	"gen",
	"kernel",
	"root",
	"tenant/library",
	"v",
}

// bundleExtraTrees are rsync'd separately; .mise/tasks is the host
// for mise task discovery.
var bundleExtraTrees = []string{
	".mise/tasks",
}

// bundleFiles are individual top-level files preserved in target.
var bundleFiles = []string{
	".bazelignore",
	".bazelrc",
	".bazelrc.user-default",
	".bazelrc.user-devcontainer",
	".bazelrc.workspace",
	".bazelversion",
	".gitignore",
	".npmrc",
	"bb.edn",
	"BUILD.bazel",
	"dprint.json",
	"go.mod",
	"go.sum",
	"go.work",
	"go.work.sum",
	"mise.toml",
	"MODULE.bazel",
	"package.json",
	"pnpm-lock.yaml",
	"tsconfig.json",
	"WORKSPACE",
	"WORKSPACE.bazel",
}

// rewriteExtensions identifies file extensions whose contents are
// candidates for module-path rewrite.
var rewriteExtensions = map[string]bool{
	".cue":   true,
	".go":    true,
	".bzl":   true,
	".bazel": true,
	".mod":   true,
}

// rewriteBasenames lists files that should be rewritten even if the
// extension doesn't match (e.g. extensionless BUILD.bazel).
var rewriteBasenames = map[string]bool{
	"BUILD.bazel":  true,
	"MODULE.bazel": true,
	"module.cue":   true,
	"go.mod":       true,
	"go.work":      true,
}

// Run dispatches on Config.Verify; init is the default action.
func (s *Service) Run(ctx context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)

	// Validate flag values up front so injection-prone interpolation
	// sites downstream never see attacker-controlled text. Per
	// AIDR-00144 security review.
	if err := validateModule("cue-module", cfg.CueModule); err != nil {
		return err
	}
	if err := validateModule("go-module", cfg.GoModule); err != nil {
		return err
	}

	srcDir, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("getwd: %w", err)
	}

	target := cfg.Target
	if target == "" {
		// No --target: default to a fresh random temp dir OUTSIDE the source
		// tree (AIDR-00148/00149). A fork nested under m/ would inherit defn's
		// config-inheritance cone (mise walks up for config, bazel resolves the
		// enclosing repo/.bazelrc/cache, git sees the ancestry) and could pass
		// while a genuinely-lifted repo fails. Verify needs an explicit target.
		if cfg.Verify {
			return fmt.Errorf("--target is required with --verify (nothing to verify without an existing fork)")
		}
		d, mkErr := os.MkdirTemp("", "defn-bootstrap-")
		if mkErr != nil {
			return fmt.Errorf("create temp target: %w", mkErr)
		}
		target = filepath.Join(d, "m")
	}
	if !filepath.IsAbs(target) {
		target = filepath.Join(srcDir, target)
	}

	sourceSHA, err := runner.Output(ctx, runner.Opts{
		Args: []string{"git", "rev-parse", "HEAD"},
		Dir:  srcDir,
	})
	if err != nil {
		return fmt.Errorf("git rev-parse HEAD in %s: %w", srcDir, err)
	}

	if cfg.Verify {
		return verifyTarget(ctx, srcDir, target, sourceSHA)
	}

	fmt.Println("defn bootstrap init:")
	fmt.Printf("  source       %s\n", srcDir)
	fmt.Printf("  target       %s\n", target)
	fmt.Printf("  CUE module   %s\n", cfg.CueModule)
	fmt.Printf("  Go module    %s\n", cfg.GoModule)
	fmt.Printf("  source SHA   %s\n", sourceSHA)
	fmt.Println()

	if err := rsyncBundle(ctx, srcDir, target); err != nil {
		return err
	}
	if err := copyBundleFiles(srcDir, target); err != nil {
		return err
	}
	if err := stubAidrAirefSkeletons(target); err != nil {
		return err
	}
	if err := stampForkTenant(target, cfg.CueModule); err != nil {
		return err
	}
	if err := rewriteModulePaths(target, cfg.CueModule, cfg.GoModule); err != nil {
		return err
	}
	if err := rewriteTenantCLIRefs(target); err != nil {
		return err
	}
	if err := filterMiseToml(target); err != nil {
		return err
	}
	if err := regenBazelrcWorkspace(ctx, target); err != nil {
		return err
	}
	if err := commitInTargetParent(ctx, target, sourceSHA); err != nil {
		return err
	}

	fmt.Println("defn bootstrap init: done")
	return nil
}

// Stop is a no-op for the bootstrap command.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles the command configuration from cobra flags.
func MakeConfig(cmd *cobra.Command, _ []string) Config {
	target, _ := cmd.Flags().GetString("target")
	cueModule, _ := cmd.Flags().GetString("cue-module")
	goModule, _ := cmd.Flags().GetString("go-module")
	verify, _ := cmd.Flags().GetBool("verify")
	return Config{
		Target:    target,
		CueModule: cueModule,
		GoModule:  goModule,
		Verify:    verify,
	}
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("target", "",
		"Target fork directory (default: a fresh random temp dir outside the source tree; relative paths resolve against the current workspace)")
	cmd.Flags().String("cue-module", defaultCueModule,
		"CUE module name for the fork (replaces github.com/defn/other)")
	cmd.Flags().String("go-module", defaultGoModule,
		"Go module name for the fork (replaces github.com/defn/other/m)")
	cmd.Flags().Bool("verify", false,
		"Report drift between the recorded source SHA in the target's parent commit history and the host's HEAD (no writes)")
}

// rsyncBundle rsyncs bundleDirs + bundleExtraTrees into target.
// Uses rsync with --delete so re-runs converge cleanly.
func rsyncBundle(ctx context.Context, srcDir, target string) error {
	for _, d := range bundleDirs {
		src := filepath.Join(srcDir, d) + "/"
		dst := filepath.Join(target, d) + "/"
		if _, err := os.Stat(filepath.Join(srcDir, d)); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return err
		}
		if err := os.MkdirAll(filepath.Dir(strings.TrimSuffix(dst, "/")), 0o755); err != nil {
			return err
		}
		if err := runner.Run(ctx, runner.Opts{
			Args: []string{
				"rsync", "-a", "--delete",
				"--exclude", ".git",
				"--exclude", "node_modules",
				src, dst,
			},
		}); err != nil {
			return fmt.Errorf("rsync %s -> %s: %w", src, dst, err)
		}
	}
	for _, d := range bundleExtraTrees {
		src := filepath.Join(srcDir, d) + "/"
		dst := filepath.Join(target, d) + "/"
		if _, err := os.Stat(filepath.Join(srcDir, d)); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return err
		}
		if err := os.MkdirAll(filepath.Dir(strings.TrimSuffix(dst, "/")), 0o755); err != nil {
			return err
		}
		if err := runner.Run(ctx, runner.Opts{
			Args: []string{"rsync", "-a", "--delete", src, dst},
		}); err != nil {
			return fmt.Errorf("rsync %s -> %s: %w", src, dst, err)
		}
	}
	return nil
}

// copyBundleFiles copies individual files from srcDir to target,
// preserving directory shape. Missing source files are skipped.
func copyBundleFiles(srcDir, target string) error {
	for _, f := range bundleFiles {
		src := filepath.Join(srcDir, f)
		dst := filepath.Join(target, f)
		data, err := os.ReadFile(src)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return fmt.Errorf("read %s: %w", src, err)
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(dst, data, 0o644); err != nil {
			return fmt.Errorf("write %s: %w", dst, err)
		}
	}
	return nil
}

// stubAidrAirefSkeletons creates empty aidr/ and airef/ dirs in the
// target with BUILD.bazel scaffolding so the gen pipeline's
// dispatch.cue claims resolve and Bazel sees the dirs.
//
// Fork starts clean per AIDR-00138 D4 (no inherited history).
func stubAidrAirefSkeletons(target string) error {
	for _, stub := range []string{"aidr", "airef"} {
		d := filepath.Join(target, stub)
		b := filepath.Join(d, "BUILD.bazel")
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
		if _, err := os.Stat(b); err == nil {
			continue
		}
		if err := os.WriteFile(b, []byte(stubBuildBazel), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", b, err)
		}
	}
	return nil
}

const stubBuildBazel = `load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = ["bazel", "bazel-build"],
)

[tagged_file(
    name = md.replace(".md", "_tag").replace("-", "_"),
    src = md,
    tags = ["aidr", "doc"],
) for md in glob(["*.md"], allow_empty = True)]

[fmt_test(
    name = "dispatch_cue_fmt",
    src = src,
    tool = "cue",
) for src in glob(["dispatch.cue"], allow_empty = True)]

[tagged_file(
    name = "dispatch_cue_tag",
    src = src,
    tags = ["cue", "source"],
) for src in glob(["dispatch.cue"], allow_empty = True)]
`

// stampForkTenant lays down the fork's leaf tenant skeleton at
// tenant/other/ inside target. Without these stubs the gen pipeline
// reads kernel/catalog/catalog.cue's `*"defn"` default and stamps
// tenant/defn/... in a fork that has no defn source tree.
func stampForkTenant(target, cueModule string) error {
	catalogDir := filepath.Join(target, "tenant", "other", "catalog")
	specDir := filepath.Join(target, "tenant", "other", "spec")
	infraDir := filepath.Join(target, "tenant", "other", "infra")
	if err := os.MkdirAll(catalogDir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(specDir, 0o755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(infraDir, ".mise", "tasks"), 0o755); err != nil {
		return err
	}

	// AIDR-00141 Stage 3.5d: stamp the fork's namesake CLI seed
	// (main.go + app/ wiring + BUILD.bazel + bin/<fork> shim) so the
	// fork can build its own `defn`-equivalent binary at //tenant/
	// other/go/cmd/other:other and run `mise run hatch` on first
	// boot. The seed lists library cmds inline; gocmd regenerates
	// modules.go on every subsequent hatch.
	cliDir := filepath.Join(target, "tenant", "other", "go", "cmd", "other")
	cliAppDir := filepath.Join(cliDir, "app")
	if err := os.MkdirAll(cliAppDir, 0o755); err != nil {
		return err
	}
	binDir := filepath.Join(target, "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		return err
	}

	writes := []struct {
		path    string
		content string
		force   bool
		mode    os.FileMode
	}{
		{filepath.Join(catalogDir, "BUILD.bazel"), catalogBuildBazel, true, 0o644},
		{filepath.Join(catalogDir, "auth.cue"), authCUE(cueModule), false, 0o644},
		{filepath.Join(catalogDir, "default-tenant.cue"), defaultTenantCUE, false, 0o644},
		{filepath.Join(specDir, "BUILD.bazel"), specBuildBazel, true, 0o644},
		{filepath.Join(specDir, "manual-files-infra.cue"), manualFilesInfraCUE, true, 0o644},
		{filepath.Join(specDir, "manual-files-tenant.cue"), manualFilesTenantCUE, true, 0o644},
		{filepath.Join(specDir, "manual-files-cli.cue"), manualFilesCLICUE, true, 0o644},
		{filepath.Join(infraDir, "mise.toml"), infraMiseToml, false, 0o644},
		{filepath.Join(infraDir, ".mise", "tasks", "BUILD.bazel"), infraTasksBuildBazel, false, 0o644},
		{filepath.Join(cliDir, "main.go"), cliMainGo(cueModule), false, 0o644},
		{filepath.Join(cliDir, "dispatch.cue"), cliDispatchCUE, false, 0o644},
		{filepath.Join(cliDir, "BUILD.bazel"), cliBuildBazel, true, 0o644},
		{filepath.Join(cliAppDir, "app.go"), cliAppGo, false, 0o644},
		{filepath.Join(cliAppDir, "modules.go"), cliModulesGo(cueModule), false, 0o644},
		{filepath.Join(cliAppDir, "dispatch.cue"), cliDispatchCUE, false, 0o644},
		{filepath.Join(cliAppDir, "BUILD.bazel"), cliAppBuildBazel, true, 0o644},
		{filepath.Join(binDir, "other"), binForkShim, true, 0o755},
		// Overwrite the bundled bin/BUILD.bazel so the fork's bin/other
		// shim is bazel-tracked (defn's bundle ships a defn-only
		// version). The replacement keeps every defn entry (the bundle
		// ships bin/defn too as a compat shim) and adds the "other"
		// entry next to it.
		{filepath.Join(binDir, "BUILD.bazel"), forkBinBuildBazel, true, 0o644},
		// var/ skeleton. The top-level var/ dir (AIDR-00145 D5.1) holds
		// workspace-derived generator output and is NOT bundled -- the
		// fork grows its own var/ on first hatch. But the two
		// content-independent BUILD.bazel files are hand-written
		// substrate the generators don't emit, so bootstrap stamps them
		// here; the fork's first hatch then populates var/ content and
		// the bazel packages resolve.
		{filepath.Join(target, "var", "BUILD.bazel"), varBuildBazel, true, 0o644},
		{filepath.Join(target, "var", "lattice", "BUILD.bazel"), varLatticeBuildBazel, true, 0o644},
		// Seed var/lattice/default_tenant.json so the fork's FIRST
		// `defn-bin!` call (in the first hatch, before any lattice
		// exists) resolves active-tenant to "other" and runs
		// //tenant/other/go/cmd/other -- not the absent
		// tenant/defn/go/cmd/defn. var/lattice isn't bundled, so this
		// is a create, not a rewrite; hatch refreshes it on first run.
		// (kernel/lib/defn.clj active-tenant reads this shard.)
		{filepath.Join(target, "var", "lattice", "default_tenant.json"), `"other"`, true, 0o644},
		// Seed an empty var/gen-chart-digests.cue (package catalog).
		// kernel/catalog/BUILD.bazel's catalog_files filegroup references
		// //var:gen-chart-digests.cue by explicit label; var/ isn't
		// bundled, so without this seed the fork's first bazel analysis
		// (hatch's //... build) fails with "no such target" before the
		// seed generator can create it. The fork has no charts, so the
		// empty form is what hatch regenerates anyway.
		{filepath.Join(target, "var", "gen-chart-digests.cue"), varGenChartDigestsSeed, true, 0o644},
	}
	for _, w := range writes {
		if !w.force {
			if _, err := os.Stat(w.path); err == nil {
				continue
			}
		}
		if err := os.MkdirAll(filepath.Dir(w.path), 0o755); err != nil {
			return fmt.Errorf("mkdir for %s: %w", w.path, err)
		}
		if err := os.WriteFile(w.path, []byte(w.content), w.mode); err != nil {
			return fmt.Errorf("write %s: %w", w.path, err)
		}
	}
	return nil
}

// varGenChartDigestsSeed is the empty (no-charts) form of
// var/gen-chart-digests.cue that bootstrap seeds so the bundled
// kernel/catalog:catalog_files reference to //var:gen-chart-digests.cue
// resolves on the fork's first bazel analysis (AIDR-00145 D5.1). hatch
// regenerates it from the fork's catalog on first run.
const varGenChartDigestsSeed = `@experiment(aliasv2,explicitopen,shortcircuit,try)

// gen-chart-digests.cue -- generated by defn gen from Bazel build output.
// DO NOT EDIT. Run: mise run gen
package catalog
`

// varBuildBazel is the top-level var/ BUILD.bazel (AIDR-00145 D5.1).
// Content-independent (glob + tagged_package) so it stays valid as the
// fork's hatch populates var/ with its own generator output.
const varBuildBazel = `"""var/ -- top-level workspace-derived generator outputs (AIDR-00145 D5.1).

A peer to kernel/ and tenant/. Holds volatile, per-workspace generator
outputs (manifest/lattice snapshots, chart digests) so that kernel/ and
tenant/ change only on structural edits, never to track regen churn.
var/ is NOT bundled by ` + "`defn bootstrap`" + ` -- this fork generates its own
var/ on first ` + "`mise run hatch`" + `. Each *.cue declares the CUE package it
logically belongs to and is re-projected into kernel/<package>/ by the
gen var overlay. All files are generated; never hand-edit.
"""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file", "tagged_package")

exports_files(glob(["*.cue"]))

filegroup(
    name = "var_files",
    srcs = glob(
        ["*.cue"],
        allow_empty = True,
    ),
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
`

// varLatticeBuildBazel is the var/lattice/ BUILD.bazel (AIDR-00145
// D5.1). glob-based so it covers whatever shard set the fork's hatch
// produces.
const varLatticeBuildBazel = `# Sharded lattice payload. Generated by go/lib/gen/lattice.
#
# All files in this directory are generated; never hand-edit. Bazel
# consumers should depend on :shards (filegroup) plus :_index.json
# explicitly when they need to locate the shard dir.

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file", "tagged_package")

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

filegroup(
    name = "shards",
    srcs = glob(
        [
            "_index.sha256",
            "*.json",
            "*.json.gz",
        ],
        allow_empty = True,
    ),
    visibility = ["//visibility:public"],
)

exports_files(["_index.json"])

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = [
        "bazel",
        "bazel-build",
    ],
)

tagged_package(exclude = ["BUILD.bazel"])
`

const catalogBuildBazel = `"""Per-tenant catalog stamped by ` + "`defn bootstrap init`" + ` (AIDR-00138)."""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file", "tagged_package")

exports_files(glob(["*.cue"]))

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
`

func authCUE(cueModule string) string {
	return `@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "` + cueModule + `/kernel/schema"

// Minimal leaf-tenant stub created by ` + "`defn bootstrap init`" + `
// (AIDR-00138 stand-in). Replace with real tenant config when the
// fork builds out its own tenancy.
auth: schema.#Auth & {tofu: "other-org"}
`
}

const defaultTenantCUE = `@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

// Pin default_tenant to this fork's leaf so gen stamps
// tenant/other/... rather than the upstream default tenant/defn.
default_tenant: "other"
`

const specBuildBazel = `"""Per-tenant spec shards stamped by ` + "`defn bootstrap init`" + ` (AIDR-00138 D5.2)."""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file", "tagged_package")

exports_files(glob(["*.cue"]))

filegroup(
    name = "spec_files",
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
`

const manualFilesInfraCUE = `@experiment(aliasv2,explicitopen,shortcircuit,try)

package contracts

_manualFileShards: infra: [
	"tenant/other/spec/manual-files-infra.cue",
	"tenant/other/infra/.mise/tasks/BUILD.bazel",
	"tenant/other/infra/mise.toml",
]
`

const manualFilesTenantCUE = `@experiment(aliasv2,explicitopen,shortcircuit,try)

package contracts

_manualFileShards: "tenant-other": [
	"tenant/other/spec/manual-files-infra.cue",
	"tenant/other/spec/manual-files-tenant.cue",
	"tenant/other/spec/BUILD.bazel",
	"tenant/other/catalog/BUILD.bazel",
]
`

const infraMiseToml = `[env]
TF_PLUGIN_CACHE_DIR = "{{env.HOME}}/.terraform.d/plugin-cache"
`

const infraTasksBuildBazel = `"""Infrastructure mise tasks (stub)."""

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
    tags = ["bazel-build"],
)
`

// AIDR-00141 Stage 3.5d: fork namesake-CLI seed. stampForkTenant
// writes these so the fork can build //tenant/other/go/cmd/other:other
// on first boot. The seed enumerates library cmds inline so the
// binary works before gocmd has had a chance to regenerate modules.go;
// every subsequent hatch refreshes modules.go from the catalog.
//
// "Other" is the fork's hardcoded tenant name (matches the rest of
// stampForkTenant). When forks become catalog-configurable, derive
// from the fork's catalog entry instead.

func cliMainGo(cueModule string) string {
	return `package main

import "` + cueModule + `/m/tenant/other/go/cmd/other/app"

func main() {
	app.Run()
}
`
}

const cliAppGo = `// Package app -- fork namesake CLI entry. Identical to defn's app
// wrapper at tenant/defn/go/cmd/defn/app/app.go; stampForkTenant
// stamps this seed so the fork has a working binary on first boot.
package app

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/defn/other/m/tenant/library/go/lib/cli"
	"github.com/defn/other/m/tenant/library/go/lib/config"
	"github.com/defn/other/m/tenant/library/go/lib/log"
	"github.com/spf13/cobra"
	"go.uber.org/fx"
	"go.uber.org/fx/fxevent"
	"go.uber.org/zap"
)

type SubCommands struct {
	fx.In
	Commands []cli.Command ` + "`group:\"subs\"`" + `
}

func Run() {
	log.Init(zap.InfoLevel)
	config.Init()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	var rootCmd *cobra.Command

	app := fx.New(
		fx.WithLogger(func() fxevent.Logger {
			return &fxevent.ZapLogger{Logger: log.Logger().Named("fx").
				WithOptions(zap.IncreaseLevel(zap.WarnLevel))}
		}),
		Modules,
		fx.Invoke(func(root *cobra.Command, subs SubCommands) error {
			rootCmd = root
			if len(subs.Commands) == 0 {
				return fmt.Errorf("no subcommands registered (modules.go missing fx.Module entries?)")
			}
			for _, sub := range subs.Commands {
				root.AddCommand(sub.GetCommand())
			}
			return nil
		}),
	)

	if err := app.Err(); err != nil {
		log.Logger().Fatal("fx construction failed", zap.Error(err))
	}

	if err := app.Start(ctx); err != nil {
		log.Logger().Fatal("start failed", zap.Error(err))
	}

	cmdErr := rootCmd.ExecuteContext(ctx)

	stopCtx, stopCancel := context.WithTimeout(context.Background(), app.StopTimeout())
	defer stopCancel()
	if err := app.Stop(stopCtx); err != nil {
		log.Logger().Fatal("stop failed", zap.Error(err))
	}

	if cmdErr != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", cmdErr)
		os.Exit(1)
	}
}
`

func cliModulesGo(cueModule string) string {
	// Library-cmd set as of AIDR-00141 Stage 4. gocmd regenerates this
	// file on every hatch from the catalog, so additions/removals of
	// library cmds (or fork-stamped cmds) propagate automatically.
	cmds := []string{
		"bootstrap", "build", "check", "dispatch", "gen", "hatch",
		"hello", "lattice", "pipeline", "root", "stamp", "sync", "version",
	}
	var imports, refs string
	for _, c := range cmds {
		imports += "\t\"" + cueModule + "/m/tenant/library/go/cmd/" + c + "\"\n"
		refs += "\t" + c + ".Module,\n"
	}
	return `// Code generated by defn gen. DO NOT EDIT.
package app

import (
` + imports + `	"go.uber.org/fx"
)

var Modules = fx.Options(
` + refs + `)
`
}

const cliDispatchCUE = `@experiment(aliasv2,explicitopen,shortcircuit,try)

// Per-brick worker declaration (AIDR-00132 OQ7). Fork stamps this as
// part of the namesake-CLI seed; edit reads/writes when the brick
// reads or writes any path not already covered by generator contracts.

package deps

import "github.com/defn/other/kernel/spec/dispatch"

worker: dispatch.#BrickResult & {
	reads: []
	writes: []
}
`

const cliBuildBazel = `load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")
load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

go_library(
    name = "other_lib",
    srcs = ["main.go"],
    importpath = "github.com/defn/other/m/tenant/other/go/cmd/other",
    visibility = ["//visibility:private"],
    deps = ["//tenant/other/go/cmd/other/app"],
)

go_binary(
    name = "other",
    embed = [":other_lib"],
    visibility = ["//visibility:public"],
)

fmt_test(name = "build_bazel_fmt", src = "BUILD.bazel", tool = "buildifier")
fmt_test(name = "main_go_fmt", src = "main.go", tool = "gofmt")

tagged_file(name = "build_bazel_tag", src = "BUILD.bazel", tags = ["bazel", "bazel-build"])
tagged_file(name = "main_go_tag", src = "main.go", tags = ["go", "source"])

[fmt_test(name = "dispatch_cue_fmt", src = src, tool = "cue") for src in glob(["dispatch.cue"], allow_empty = True)]

[tagged_file(name = "dispatch_cue_tag", src = src, tags = ["cue", "source"]) for src in glob(["dispatch.cue"], allow_empty = True)]
`

const cliAppBuildBazel = `load("@io_bazel_rules_go//go:def.bzl", "go_library")
load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

go_library(
    name = "app",
    srcs = ["app.go", "modules.go"],
    importpath = "github.com/defn/other/m/tenant/other/go/cmd/other/app",
    visibility = ["//tenant/other/go/cmd/other:__pkg__"],
    deps = [
        "//tenant/library/go/cmd/bootstrap",
        "//tenant/library/go/cmd/build",
        "//tenant/library/go/cmd/check",
        "//tenant/library/go/cmd/dispatch",
        "//tenant/library/go/cmd/gen",
        "//tenant/library/go/cmd/hatch",
        "//tenant/library/go/cmd/hello",
        "//tenant/library/go/cmd/lattice",
        "//tenant/library/go/cmd/pipeline",
        "//tenant/library/go/cmd/root",
        "//tenant/library/go/cmd/stamp",
        "//tenant/library/go/cmd/sync",
        "//tenant/library/go/cmd/version",
        "//tenant/library/go/lib/cli",
        "//tenant/library/go/lib/config",
        "//tenant/library/go/lib/log",
        "@com_github_spf13_cobra//:cobra",
        "@org_uber_go_fx//:fx",
        "@org_uber_go_fx//fxevent",
        "@org_uber_go_zap//:zap",
    ],
)

fmt_test(name = "build_bazel_fmt", src = "BUILD.bazel", tool = "buildifier")
fmt_test(name = "app_go_fmt", src = "app.go", tool = "gofmt")
fmt_test(name = "modules_go_fmt", src = "modules.go", tool = "gofmt")

tagged_file(name = "build_bazel_tag", src = "BUILD.bazel", tags = ["bazel", "bazel-build"])
tagged_file(name = "app_go_tag", src = "app.go", tags = ["go", "source"])
tagged_file(name = "modules_go_tag", src = "modules.go", tags = ["generated", "go"])

[fmt_test(name = "dispatch_cue_fmt", src = src, tool = "cue") for src in glob(["dispatch.cue"], allow_empty = True)]

[tagged_file(name = "dispatch_cue_tag", src = src, tags = ["cue", "source"]) for src in glob(["dispatch.cue"], allow_empty = True)]
`

const manualFilesCLICUE = `@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard stamped by ` + "`defn bootstrap init`" + ` for the
// fork's namesake CLI seed (AIDR-00141 Stage 3.5d). main.go + app/
// wiring are hand-editable seeds; modules.go is regenerated by gocmd.

package contracts

_manualFileShards: cli: [
	"tenant/other/spec/manual-files-cli.cue",
	"tenant/other/go/cmd/other/BUILD.bazel",
	"tenant/other/go/cmd/other/dispatch.cue",
	"tenant/other/go/cmd/other/main.go",
	"tenant/other/go/cmd/other/app/BUILD.bazel",
	"tenant/other/go/cmd/other/app/app.go",
	"tenant/other/go/cmd/other/app/dispatch.cue",
	"tenant/other/go/cmd/other/app/modules.go",
	"bin/other",
]
`

const forkBinBuildBazel = `load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

# All git-tracked files in this package must be registered with Bazel.
# bin/other is the fork's namesake-CLI shim (AIDR-00141 Stage 3.5d);
# bin/defn rides via the kernel bundle as a compat alias that also
# resolves to the active tenant's CLI through ` + "`mise run defn`" + `.
exports_files([
    "bazel-runner",
    "bbs",
    "bootstrap-bazelrc",
    "defn",
    "k3k",
    "other",
    "yae",
])

fmt_test(name = "build_bazel_fmt", src = "BUILD.bazel", tool = "buildifier")
fmt_test(name = "bbs_fmt", src = "bbs", tool = "shfmt")
fmt_test(name = "yae_fmt", src = "yae", tool = "shfmt")
fmt_test(name = "bazel_runner_fmt", src = "bazel-runner", tool = "shfmt")
fmt_test(name = "bootstrap_bazelrc_fmt", src = "bootstrap-bazelrc", tool = "shfmt")
fmt_test(name = "defn_fmt", src = "defn", tool = "cljstyle")
fmt_test(name = "k3k_fmt", src = "k3k", tool = "shfmt")
fmt_test(name = "other_fmt", src = "other", tool = "cljstyle")

tagged_file(name = "build_bazel_tag", src = "BUILD.bazel", tags = ["bazel-build"])
tagged_file(name = "bazel_runner_tag", src = "bazel-runner", tags = ["script", "shell"])
tagged_file(name = "bootstrap_bazelrc_tag", src = "bootstrap-bazelrc", tags = ["script", "shell"])
tagged_file(name = "bbs_tag", src = "bbs", tags = ["script", "shell"])
tagged_file(name = "yae_tag", src = "yae", tags = ["script", "shell"])
tagged_file(name = "defn_tag", src = "defn", tags = ["clojure", "script"])
tagged_file(name = "k3k_tag", src = "k3k", tags = ["script", "shell"])
tagged_file(name = "other_tag", src = "other", tags = ["clojure", "script"])

[fmt_test(
    name = "dispatch_cue_fmt",
    src = src,
    tool = "cue",
) for src in glob(["dispatch.cue"], allow_empty = True)]

[tagged_file(
    name = "dispatch_cue_tag",
    src = src,
    tags = ["cue", "source"],
) for src in glob(["dispatch.cue"], allow_empty = True)]
`

const binForkShim = `#!/usr/bin/env bbs
;; bin/other -- fork namesake CLI shim (AIDR-00141 Stage 3.5d).
;; Delegates to ` + "`mise run defn`" + `, which reads default_tenant from the
;; lattice and builds //tenant/<t>/go/cmd/<t>:<t> -- the same task
;; serves every tenant's namesake CLI.

(require '[babashka.process :as p])

(p/exec (into ["mise" "run" "defn" "--"] *command-line-args*))
`

// rewriteModulePaths walks the target tree and replaces upstream
// CUE+Go module strings with the fork's modules.
//
// Order matters: rewrite the longer Go module path FIRST so it
// doesn't get half-clobbered by the CUE rewrite. .pb.go files embed
// length-prefixed protobuf descriptors whose binary string contains
// the upstream package name; a naive text replace corrupts the
// length prefix, so those are skipped.
func rewriteModulePaths(target, cueModule, goModule string) error {
	return filepath.WalkDir(target, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if !shouldRewrite(path) {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("read %s: %w", path, err)
		}
		orig := string(data)
		next := strings.ReplaceAll(orig, "github.com/defn/other/m", goModule)
		next = strings.ReplaceAll(next, "github.com/defn/other", cueModule)
		if next == orig {
			return nil
		}
		if err := os.WriteFile(path, []byte(next), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", path, err)
		}
		return nil
	})
}

func shouldRewrite(path string) bool {
	name := filepath.Base(path)
	if strings.HasSuffix(name, ".pb.go") {
		return false
	}
	ext := filepath.Ext(name)
	if rewriteExtensions[ext] {
		return true
	}
	return rewriteBasenames[name]
}

// tenantCLIRefRe matches `tenant/defn/go/cmd/defn` only as a
// path-component-bounded substring -- preceded by `/` or `"` and
// followed by `/`, `:`, or `"`. Used by rewriteTenantCLIRefs to
// rewrite bazel labels, go import strings, and bazel-bin paths
// without silently corrupting a future bundle file that mentions
// the literal in a docstring / error message / sample text. Per
// AIDR-00144 security review (minor).
var tenantCLIRefRe = regexp.MustCompile(`([/"])tenant/defn/go/cmd/defn([/:"])`)

// rewriteTenantCLIRefs replaces upstream tenant/defn/go/cmd/defn
// references with tenant/other/go/cmd/other so the fork's bundled
// kernel/spec/BUILD.bazel + other Bazel files target the fork's
// namesake CLI instead of defn's (which doesn't exist in the fork).
// Per AIDR-00141 Stage 3.5d. Only the specific cmd path is rewritten;
// other "tenant/defn/" references (catalog seeds, etc.) are left
// alone because they belong to defn-specific subtrees that the fork
// won't have but that won't break Bazel analysis (no targets there).
func rewriteTenantCLIRefs(target string) error {
	return filepath.WalkDir(target, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if !shouldRewrite(path) {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("read %s: %w", path, err)
		}
		orig := string(data)
		// Longest match first so `tenant/other/go/cmd/other:other` is fully
		// rewritten to `tenant/other/go/cmd/other:other` before the
		// shorter regex match would leave `:defn` behind.
		next := strings.ReplaceAll(orig, "tenant/other/go/cmd/other:other", "tenant/other/go/cmd/other:other")
		next = strings.ReplaceAll(next, "tenant/other/go/cmd/other/other_/other", "tenant/other/go/cmd/other/other_/other")
		// Anchored rewrite for the remaining bazel-label / go-import /
		// bazel-bin path forms; refuses to corrupt unanchored mentions.
		next = tenantCLIRefRe.ReplaceAllString(next, "${1}tenant/other/go/cmd/other${2}")
		if next == orig {
			return nil
		}
		if err := os.WriteFile(path, []byte(next), 0o644); err != nil {
			return fmt.Errorf("write %s: %w", path, err)
		}
		return nil
	})
}

// filterMiseToml drops `tenant/{boot,defn}/` lines from
// task_config.includes -- those tenants don't ship in the bundle
// and their includes would 404.
func filterMiseToml(target string) error {
	path := filepath.Join(target, "mise.toml")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("read %s: %w", path, err)
	}
	orig := string(data)
	drop := regexp.MustCompile(`^\s*"tenant/(boot|defn)/`)
	var kept []string
	for _, line := range strings.Split(orig, "\n") {
		if drop.MatchString(line) {
			continue
		}
		kept = append(kept, line)
	}
	out := strings.Join(kept, "\n")
	if !strings.HasSuffix(out, "\n") {
		out += "\n"
	}
	if out == orig {
		return nil
	}
	return os.WriteFile(path, []byte(out), 0o644)
}

// regenBazelrcWorkspace runs `bin/bootstrap-bazelrc` inside the
// target so .bazelrc.workspace reflects the fork's filesystem
// location (HOME, MISE_CONFIG_FILE, sandbox_writable_path) rather
// than the host's.
func regenBazelrcWorkspace(ctx context.Context, target string) error {
	script := filepath.Join(target, "bin", "bootstrap-bazelrc")
	if _, err := os.Stat(script); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return runner.Run(ctx, runner.Opts{
		Args: []string{script},
		Dir:  target,
	})
}

// verifyTarget reports drift between a target fork and its source.
//
// Three layers of analysis, surfaced in order:
//
//  1. Source-SHA drift: recorded "bootstrap from defn@<sha>" in the
//     target's parent history vs the source's current HEAD.
//  2. Bundle drift: `git diff --name-only <recorded>..<HEAD>` restricted
//     to the bundle pathspec (bundleDirs + bundleExtraTrees + bundleFiles).
//     Lists which source files would propagate to the fork on re-bootstrap.
//  3. Rewrite-equivalence: `git worktree add` at recorded SHA, re-run the
//     bootstrap rewrite into a temp dir, diff vs actual target, filter out
//     generator-claimed paths via hatch.LoadGeneratorClaims. The diff that
//     survives is the set of bundle files the fork has edited
//     post-bootstrap (the load-bearing flag: re-bootstrap will overwrite
//     them). The intersection with layer 2 is the re-bootstrap conflict
//     set: source moved AND fork edited, same file.
//
// Exit semantics:
//   - target at source HEAD                  -> nil
//   - SHA drifts, bundle clean               -> nil (re-bootstrap is a
//     content no-op; only the recorded SHA pointer would advance)
//   - SHA drifts, bundle dirty, fork clean   -> nil (re-bootstrap will
//     change N files but the fork has no local edits to lose)
//   - SHA drifts, fork has bundle edits      -> error (re-bootstrap will
//     overwrite M fork-edited files; operator must reconcile)
//
// Layer 3 deliberately re-runs the rewrite from the worktree-at-recorded-SHA
// rather than from current HEAD: the goal is to recover "what did bootstrap
// originally produce in this fork?" so we can detect what the fork has
// edited *since*. Comparing against current HEAD would conflate fork edits
// with upstream advances.
func verifyTarget(ctx context.Context, srcDir, target, srcHeadSHA string) error {
	parent := filepath.Dir(target)
	base := filepath.Base(target)

	if _, err := os.Stat(filepath.Join(parent, ".git")); err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("verify: %s is not a git repo (no parent .git directory)", parent)
		}
		return err
	}

	// Find the most recent "bootstrap from defn@<sha>" commit in the
	// parent's history touching the target subtree. The fork's
	// history typically interleaves bootstrap commits with "fork:
	// post-bootstrap hatch outputs" commits, so we scan back rather
	// than reading just the latest.
	gitLog, err := runner.Output(ctx, runner.Opts{
		Args: []string{
			"git", "log",
			"--pretty=format:%H %s",
			"--", base,
		},
		Dir: parent,
	})
	if err != nil {
		return fmt.Errorf("verify: git log in %s: %w", parent, err)
	}

	const prefix = "bootstrap from defn@"
	var recordedSHA, commitSHA string
	if gitLog == "" {
		return fmt.Errorf("verify: %s has no commit history touching %s -- has `defn bootstrap init` been run?", parent, base)
	}
	for _, line := range strings.Split(gitLog, "\n") {
		parts := strings.SplitN(line, " ", 2)
		if len(parts) < 2 {
			continue
		}
		if strings.HasPrefix(parts[1], prefix) {
			commitSHA = parts[0]
			recordedSHA = strings.TrimSpace(strings.TrimPrefix(parts[1], prefix))
			break
		}
	}

	cueModule := readCUEModule(target)
	goModule := readGoModule(target)

	fmt.Println("defn bootstrap verify:")
	fmt.Printf("  source             %s\n", srcDir)
	fmt.Printf("  target             %s\n", target)
	if recordedSHA != "" {
		fmt.Printf("  bootstrap commit   %s\n", commitSHA)
		fmt.Printf("  recorded SHA       %s\n", recordedSHA)
	} else {
		fmt.Printf("  bootstrap commit   <not found> (no 'bootstrap from defn@<sha>' commit in parent history)\n")
	}
	fmt.Printf("  host HEAD          %s\n", srcHeadSHA)
	if cueModule != "" {
		fmt.Printf("  CUE module         %s\n", cueModule)
	}
	if goModule != "" {
		fmt.Printf("  Go module          %s\n", goModule)
	}
	fmt.Println()

	if recordedSHA == "" {
		fmt.Println("verify: cannot compute drift -- recorded SHA missing")
		return fmt.Errorf("verify: target's last commit is not a bootstrap commit")
	}

	shaDrift := recordedSHA != srcHeadSHA
	if !shaDrift {
		fmt.Println("verify: no SHA drift -- target is at source HEAD")
	} else {
		fmt.Printf("verify: SHA drift -- target was bootstrapped from %s, source HEAD is %s\n", recordedSHA, srcHeadSHA)
	}

	// Layer 2: bundle drift (source advances)
	var bundleDrift []string
	if shaDrift {
		bundleDrift, err = bundleDriftFiles(ctx, srcDir, recordedSHA, srcHeadSHA)
		if err != nil {
			fmt.Printf("verify: (cannot enumerate bundle drift: %v -- treating as dirty)\n", err)
		} else if len(bundleDrift) == 0 {
			fmt.Println("verify: bundle clean -- recorded SHA differs but no bundled files changed in source between recorded SHA and HEAD")
		} else {
			fmt.Printf("verify: %d bundled file(s) changed in source between %s..%s\n", len(bundleDrift), short(recordedSHA), short(srcHeadSHA))
		}
	}

	// Layer 3: rewrite-equivalence (fork edits)
	if cueModule == "" || goModule == "" {
		fmt.Println("verify: skipping rewrite-equivalence -- cannot read module names from target")
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}
	// Re-validate the round-tripped module values before feeding them
	// back into rederiveExpectedTarget -> stampForkTenant. The
	// readCUEModule / readGoModule regexes are permissive (any
	// non-quote chars accepted); the target's module files could have
	// been edited post-bootstrap to inject text that would re-enter
	// the seed templates on every verify. Per AIDR-00144.
	if err := validateModule("cue-module (from target/cue.mod/module.cue)", cueModule); err != nil {
		fmt.Printf("verify: skipping rewrite-equivalence -- %v\n", err)
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}
	if err := validateModule("go-module (from target/go.mod)", goModule); err != nil {
		fmt.Printf("verify: skipping rewrite-equivalence -- %v\n", err)
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}

	worktreeDir, cleanupWT, err := makeSourceWorktree(ctx, srcDir, recordedSHA)
	if err != nil {
		fmt.Printf("verify: (cannot create worktree at %s: %v -- skipping rewrite-equivalence)\n", short(recordedSHA), err)
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}
	defer cleanupWT()

	tempTarget, cleanupTT, err := makeTempTarget()
	if err != nil {
		fmt.Printf("verify: (cannot create temp target: %v -- skipping rewrite-equivalence)\n", err)
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}
	defer cleanupTT()

	if err := rederiveExpectedTarget(ctx, worktreeDir, tempTarget, cueModule, goModule); err != nil {
		fmt.Printf("verify: (cannot re-derive expected target: %v -- skipping rewrite-equivalence)\n", err)
		return finishVerify(target, shaDrift, bundleDrift, nil)
	}

	claims, err := hatch.LoadGeneratorClaims(worktreeDir)
	if err != nil {
		fmt.Printf("verify: (cannot load generator claims: %v -- using stamp-only allow-list)\n", err)
		claims = nil
	}
	allowList := buildAllowList(claims)

	forkEdited, err := classifyForkEdits(tempTarget, target, allowList)
	if err != nil {
		return fmt.Errorf("verify: classify fork edits: %w", err)
	}

	return finishVerify(target, shaDrift, bundleDrift, forkEdited)
}

// finishVerify prints the summary tables and returns the appropriate exit
// error. Centralized so the early-out paths above (skipped layer-3 due to
// worktree or rewrite failure) reach the same UX.
func finishVerify(target string, shaDrift bool, bundleDrift, forkEdited []string) error {
	const maxShow = 30

	if !shaDrift {
		return nil
	}

	if len(bundleDrift) > 0 {
		fmt.Println()
		fmt.Printf("verify: bundle drift (source moves since recorded SHA): %d file(s)\n", len(bundleDrift))
		for i, f := range bundleDrift {
			if i >= maxShow {
				fmt.Printf("  ... and %d more\n", len(bundleDrift)-maxShow)
				break
			}
			fmt.Printf("  %s\n", f)
		}
	}

	if len(forkEdited) > 0 {
		fmt.Println()
		fmt.Printf("verify: fork edits in bundle (re-bootstrap will OVERWRITE): %d file(s)\n", len(forkEdited))
		for i, f := range forkEdited {
			if i >= maxShow {
				fmt.Printf("  ... and %d more\n", len(forkEdited)-maxShow)
				break
			}
			fmt.Printf("  %s\n", f)
		}
	}

	// Conflict set = files in both lists. Bundle-drift paths are
	// git-root-relative (m/...); fork-edited paths are target-relative.
	// Strip the m/ prefix from bundle-drift when computing the intersection.
	if len(bundleDrift) > 0 && len(forkEdited) > 0 {
		bd := make(map[string]bool, len(bundleDrift))
		for _, p := range bundleDrift {
			bd[strings.TrimPrefix(p, "m/")] = true
		}
		var conflicts []string
		for _, f := range forkEdited {
			if bd[f] {
				conflicts = append(conflicts, f)
			}
		}
		if len(conflicts) > 0 {
			fmt.Println()
			fmt.Printf("verify: CONFLICTS on re-bootstrap (source moved AND fork edited, same file): %d\n", len(conflicts))
			for i, f := range conflicts {
				if i >= maxShow {
					fmt.Printf("  ... and %d more\n", len(conflicts)-maxShow)
					break
				}
				fmt.Printf("  %s\n", f)
			}
		}
	}

	fmt.Println()
	switch {
	case len(forkEdited) > 0:
		fmt.Printf("(re-bootstrap will overwrite %d fork-edited file(s); reconcile before `defn bootstrap init --target=%s`)\n", len(forkEdited), target)
		return fmt.Errorf("verify: drift detected (%d fork-edited files in bundle)", len(forkEdited))
	case len(bundleDrift) > 0:
		fmt.Printf("(fork has no local edits in bundle area; safe to `defn bootstrap init --target=%s` -- it will advance %d files cleanly)\n", target, len(bundleDrift))
		return nil
	default:
		fmt.Println("(SHA pointer differs but bundle is content-equal; re-bootstrap is a no-op)")
		return nil
	}
}

// bundleDriftFiles returns the bundled files that changed in source
// between recordedSHA and headSHA. Bundle pathspec covers
// bundleDirs + bundleExtraTrees + bundleFiles -- the same set that
// `defn bootstrap init` copies into the target. Non-bundle paths
// (tenant/defn/, aidr/, airef/, root/ outside the bundle set) are
// filtered out by git's pathspec, so the result lists only files
// whose change would propagate into the fork on re-bootstrap.
func bundleDriftFiles(ctx context.Context, srcDir, recordedSHA, headSHA string) ([]string, error) {
	var pathspec []string
	pathspec = append(pathspec, bundleDirs...)
	pathspec = append(pathspec, bundleExtraTrees...)
	pathspec = append(pathspec, bundleFiles...)

	args := []string{"git", "diff", "--name-only", recordedSHA + ".." + headSHA, "--"}
	args = append(args, pathspec...)

	out, err := runner.Output(ctx, runner.Opts{Args: args, Dir: srcDir})
	if err != nil {
		return nil, fmt.Errorf("git diff %s..%s in %s: %w", recordedSHA, headSHA, srcDir, err)
	}
	var files []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		files = append(files, line)
	}
	return files, nil
}

// makeSourceWorktree adds a temporary git worktree at recordedSHA and
// returns the in-worktree m/ subdir path plus a cleanup function. The
// cleanup runs `git worktree remove --force` and falls back to
// RemoveAll so /tmp doesn't accumulate.
func makeSourceWorktree(ctx context.Context, srcDir, recordedSHA string) (string, func(), error) {
	tmp, err := os.MkdirTemp("", "defn-verify-wt-")
	if err != nil {
		return "", func() {}, fmt.Errorf("mktemp worktree: %w", err)
	}
	devnull := discardWriter{}
	if err := runner.Run(ctx, runner.Opts{
		Args:   []string{"git", "worktree", "add", "--detach", tmp, recordedSHA},
		Dir:    srcDir,
		Stdout: devnull,
		Stderr: devnull,
	}); err != nil {
		_ = os.RemoveAll(tmp)
		return "", func() {}, fmt.Errorf("git worktree add %s at %s: %w", tmp, recordedSHA, err)
	}
	cleanup := func() {
		_ = runner.Run(context.Background(), runner.Opts{
			Args:   []string{"git", "worktree", "remove", "--force", tmp},
			Dir:    srcDir,
			Stdout: devnull,
			Stderr: devnull,
		})
		_ = os.RemoveAll(tmp)
	}
	// srcDir is /Users/.../m; the worktree contains the entire parent
	// git tree at the recorded SHA. The bootstrap pipeline operates on
	// the m/ subdir of that. Compute the in-worktree m/ path.
	mDir := tmp
	parentGitRoot := filepath.Dir(srcDir)
	if relSub, err := filepath.Rel(parentGitRoot, srcDir); err == nil && relSub != "." {
		mDir = filepath.Join(tmp, relSub)
	}
	return mDir, cleanup, nil
}

// discardWriter satisfies io.Writer with a sink so worktree commands
// don't leak chatter into the verify output. Drop-in for io.Discard
// without importing io purely for that name.
type discardWriter struct{}

func (discardWriter) Write(p []byte) (int, error) { return len(p), nil }

// makeTempTarget creates a fresh temp directory that the re-derived
// bootstrap target will be written into. Cleanup function removes it.
func makeTempTarget() (string, func(), error) {
	tmp, err := os.MkdirTemp("", "defn-verify-tt-")
	if err != nil {
		return "", func() {}, fmt.Errorf("mktemp temp-target: %w", err)
	}
	cleanup := func() { _ = os.RemoveAll(tmp) }
	return tmp, cleanup, nil
}

// rederiveExpectedTarget runs the bootstrap rewrite pipeline against
// the worktree-at-recordedSHA, writing into tempTarget. Mirrors the
// init flow but skips host-coupled steps:
//
//   - regenBazelrcWorkspace (host-specific paths)
//   - commitInTargetParent (temp target has no parent .git)
//
// The result is "what `defn bootstrap init` would have produced at
// recordedSHA against this fork's modules" -- the reference for
// classifying which bundle files the fork has edited post-bootstrap.
func rederiveExpectedTarget(ctx context.Context, worktreeDir, tempTarget, cueModule, goModule string) error {
	if err := rsyncBundle(ctx, worktreeDir, tempTarget); err != nil {
		return err
	}
	if err := copyBundleFiles(worktreeDir, tempTarget); err != nil {
		return err
	}
	if err := stubAidrAirefSkeletons(tempTarget); err != nil {
		return err
	}
	if err := stampForkTenant(tempTarget, cueModule); err != nil {
		return err
	}
	if err := rewriteModulePaths(tempTarget, cueModule, goModule); err != nil {
		return err
	}
	if err := filterMiseToml(tempTarget); err != nil {
		return err
	}
	return nil
}

// buildAllowList combines generator-claimed paths with the one-shot
// stamped paths from stampForkTenant. Files in the allow-list are silent
// in the fork-edit classification because:
//
//   - Generator-claimed paths are regenerated by the fork's `mise run hatch`.
//     Differences vs the temp-target are expected (the fork's lattice/manifest
//     content reflects the fork's tenant set, not the source's).
//   - One-shot stamped paths (force:false in stampForkTenant) are seeds that
//     bootstrap creates only if missing; the fork is expected to evolve them
//     (auth, default-tenant override).
//
// Hardcoded fork-tenant name "other" matches the current bootstrap default.
// When the forks-catalog-field lands (AIDR-00140 carry-forward), derive the
// fork name from the catalog entry.
func buildAllowList(claims map[string][]string) map[string]bool {
	out := make(map[string]bool, 256)
	for _, paths := range claims {
		for _, p := range paths {
			out[p] = true
		}
	}
	const forkName = "other"
	out[fmt.Sprintf("tenant/%s/catalog/auth.cue", forkName)] = true
	out[fmt.Sprintf("tenant/%s/catalog/default-tenant.cue", forkName)] = true
	out[fmt.Sprintf("tenant/%s/infra/mise.toml", forkName)] = true
	out[fmt.Sprintf("tenant/%s/infra/.mise/tasks/BUILD.bazel", forkName)] = true

	// Tooling-mutated files declared as `manual` in
	// kernel/spec/manual-files-*.cue but actually rewritten by hatch /
	// go workspace tooling at fork-build time. Not operator-authored,
	// so not "fork edits" in the verify-classification sense.
	out["go.work.sum"] = true
	out["kernel/spec/sync-files.txt"] = true
	return out
}

// classifyForkEdits walks expectedTarget (the re-derived rewrite output)
// and compares each file to its counterpart in actualTarget. Returns the
// list of bundle paths where bytes differ AND the path is NOT in allowList
// -- i.e., the fork has edited the file post-bootstrap. These are the
// files re-bootstrap would overwrite.
//
// Comparison is one-directional intentionally: walking only the expected
// tree filters out fork-only content (aidr/, airef/, post-bootstrap
// commits in tenant/<fork>/) because those paths never appear in expected.
// Files the fork has *added* inside a bundle path (e.g. a new file under
// kernel/) would show up in actual but not expected; those are out of
// scope for the MVP -- the dominant risk is fork editing an existing
// bundle file, not adding a new one.
func classifyForkEdits(expectedTarget, actualTarget string, allowList map[string]bool) ([]string, error) {
	var edited []string
	err := filepath.WalkDir(expectedTarget, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(expectedTarget, path)
		if err != nil {
			return err
		}
		if !pathInBundle(rel) {
			return nil
		}
		if allowList[rel] {
			return nil
		}
		actualPath := filepath.Join(actualTarget, rel)
		expBytes, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("read expected %s: %w", path, err)
		}
		actBytes, err := os.ReadFile(actualPath)
		if err != nil {
			if os.IsNotExist(err) {
				edited = append(edited, rel)
				return nil
			}
			return fmt.Errorf("read actual %s: %w", actualPath, err)
		}
		if !bytes.Equal(expBytes, actBytes) {
			edited = append(edited, rel)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(edited)
	return edited, nil
}

// pathInBundle reports whether the given target-relative path is inside
// one of the bundle areas bootstrap copies. Paths outside (aidr/, airef/,
// tenant/<fork>/ beyond the stamp) are out of scope for fork-edit
// classification.
func pathInBundle(rel string) bool {
	rel = filepath.ToSlash(rel)
	for _, d := range bundleDirs {
		if rel == d || strings.HasPrefix(rel, d+"/") {
			return true
		}
	}
	for _, t := range bundleExtraTrees {
		if rel == t || strings.HasPrefix(rel, t+"/") {
			return true
		}
	}
	for _, f := range bundleFiles {
		if rel == f {
			return true
		}
	}
	return false
}

// short truncates a SHA for compact log lines. The full SHA is still
// printed in the header block above.
func short(sha string) string {
	if len(sha) > 8 {
		return sha[:8]
	}
	return sha
}

// readCUEModule parses target/cue.mod/module.cue for `module:` value.
// Returns empty string on any I/O or parse failure (verify is
// informational, not a hard contract here).
func readCUEModule(target string) string {
	data, err := os.ReadFile(filepath.Join(target, "cue.mod", "module.cue"))
	if err != nil {
		return ""
	}
	re := regexp.MustCompile(`module:\s*"([^"]+)"`)
	m := re.FindSubmatch(data)
	if len(m) < 2 {
		return ""
	}
	return string(m[1])
}

// readGoModule parses target/go.mod for its `module <name>` directive.
func readGoModule(target string) string {
	data, err := os.ReadFile(filepath.Join(target, "go.mod"))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "module "))
		}
	}
	return ""
}

// commitInTargetParent runs `git add -A m && git commit` in the
// parent directory of target so the fork's history pins its
// provenance. Skips silently if the parent is not a git repo or the
// commit is a no-op.
func commitInTargetParent(ctx context.Context, target, sourceSHA string) error {
	parent := filepath.Dir(target)
	base := filepath.Base(target)
	if _, err := os.Stat(filepath.Join(parent, ".git")); err != nil {
		if os.IsNotExist(err) {
			fmt.Printf("warning: %s is not a git repo; skipping commit. Run `git init` there first.\n", parent)
			return nil
		}
		return err
	}
	// `-A` is safe here because `base` is the freshly-stamped fork
	// subtree and its content is constrained to bundleDirs +
	// bundleExtraTrees + bundleFiles + the stampForkTenant /
	// stampForkCLI seed files. The kernel bundle carries no secrets
	// (no `.env`, no credentials paths -- bundleDirs is the allowlist
	// and rsync runs with --exclude .git --exclude node_modules);
	// the stamp seeds are pure scaffolding text. Per AIDR-00144 code
	// review (minor): documenting the deliberate choice.
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "add", "-A", base},
		Dir:  parent,
	}); err != nil {
		return fmt.Errorf("git add in %s: %w", parent, err)
	}
	msg := fmt.Sprintf("bootstrap from defn@%s", sourceSHA)
	if err := runner.Run(ctx, runner.Opts{
		Args: []string{"git", "commit", "-m", msg},
		Dir:  parent,
	}); err != nil {
		fmt.Printf("no commit (probably no-op): %v\n", err)
		return nil
	}
	return nil
}
