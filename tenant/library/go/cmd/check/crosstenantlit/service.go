// Package crosstenantlit provides the `defn check crosstenantlit`
// subcommand: AIDR-00102's cross-tenant literal vet (SPEC-00352).
// The check is the tenant-side complement of SPEC-00351 (kernel-side
// fork-readiness). It walks every leaf tenant's source tree and
// forbids string literals naming any other leaf tenant or any other
// leaf tenant's auth profile values, with structural exceptions for
// the catalog-borrow declaration (tenant/T/catalog/auth.cue) and
// generator-output paths (per AIDR-00097's brick_io.writes union).
//
// Exit-code contract (matches the AIDR-00099 #Check schema):
//
//	0 -- clean: no forbidden literal in any tenant tree.
//	1 -- violations: one line per Violation.Format() on stdout.
//	2 -- usage / IO error: diagnostic on stderr.
//
// Workdir discovery walks up from the current directory looking for
// cue.mod/module.cue. The --workdir flag overrides the discovery for
// callers (e.g. Bazel sh_tests) whose cwd is not inside the workspace.
//
// All input data (tenant trees, file contents, brick_io.writes) is
// derived from the merged lattice JSON + a CUE eval of the same
// contracts package set as brickcollision -- no direct filesystem
// walk of tenant/, so the sh_test data deps mirror brick_collision_vet.
package crosstenantlit

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	cuelang "cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
	"github.com/defn/other/m/tenant/library/go/lib/spec"
	"github.com/defn/other/m/tenant/library/go/lib/spec/crosstenantlit"
	"github.com/spf13/cobra"
)

type Config struct {
	WorkDir string
}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	workDir, err := resolveWorkDir(cfg.WorkDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	latticeBytes, err := spec.MergeShards(filepath.Join(workDir, "var", "lattice"))
	if err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("merge lattice shards: %w", err))
		os.Exit(2)
	}
	var lat spec.Lattice
	if err := json.Unmarshal(latticeBytes, &lat); err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("decode lattice: %w", err))
		os.Exit(2)
	}
	tenants, files := discover(&lat)
	if err := resolveProfiles(workDir, tenants); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	genWrites, err := loadGenWrites(workDir, latticeBytes)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	violations := crosstenantlit.Check(tenants, files, genWrites)
	if len(violations) == 0 {
		fmt.Println("ok")
		return nil
	}
	leafs := crosstenantlit.LeafNames(tenants)
	for _, v := range violations {
		fmt.Println(v.Format(leafs))
	}
	os.Exit(1)
	return nil
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(cmd *cobra.Command, _ []string) Config {
	w, _ := cmd.Flags().GetString("workdir")
	return Config{WorkDir: w}
}

func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("workdir", "", "workspace root containing cue.mod/module.cue (defaults to walking up from cwd)")
}

func resolveWorkDir(override string) (string, error) {
	if override != "" {
		abs, err := filepath.Abs(override)
		if err != nil {
			return "", fmt.Errorf("resolve --workdir: %w", err)
		}
		// Require cue.mod/module.cue even on explicit override:
		// running `defn check crosstenantlit --workdir /etc` should
		// not silently glob /etc's .cue files into a CUE instance.
		// AIDR-00103 closed this developer foot-gun.
		if _, err := os.Stat(filepath.Join(abs, "cue.mod", "module.cue")); err != nil {
			return "", fmt.Errorf("--workdir %s: cue.mod/module.cue not found", abs)
		}
		return abs, nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	d := cwd
	for {
		if _, err := os.Stat(filepath.Join(d, "cue.mod", "module.cue")); err == nil {
			return d, nil
		}
		parent := filepath.Dir(d)
		if parent == d {
			return "", fmt.Errorf("cue.mod/module.cue not found above %s", cwd)
		}
		d = parent
	}
}

// allowedExt is the file-extension scope per AIDR-00102 + AIDR-00103
// review: SPEC-00351's set plus .tf and .toml (legitimate hardcodes
// during AIDR-00101) plus .bazel (BUILD.bazel cross-tenant literals
// are skipped via gen_writes when generator-claimed; hand-edited
// tenant BUILD.bazel files now fail loudly). The label-aliasing
// concern from AIDR-00102 Q1 is a different surface (label, not
// literal) and remains a separate sp-options follow-up.
var allowedExt = map[string]bool{
	".go":    true,
	".cue":   true,
	".bzl":   true,
	".clj":   true,
	".tf":    true,
	".toml":  true,
	".bazel": true,
}

// discover reads the lattice tree and returns the classified tenant
// list and per-leaf source file list. Tenants live under
// tree.dirs.m.dirs.tenant. A tenant is leaf iff
// catalog/auth.cue exists in its subtree. Profile values are filled
// in by resolveProfiles via cue eval -- not parsed from the file
// content here -- so CUE references and defaults resolve to the same
// strings downstream generators see.
func discover(lat *spec.Lattice) ([]crosstenantlit.Tenant, []crosstenantlit.SourceFile) {
	tenantDir := lookupSub(&lat.Tree, "m", "tenant")
	if tenantDir == nil {
		return nil, nil
	}
	var tenants []crosstenantlit.Tenant
	for name, sub := range tenantDir.Dirs {
		t := crosstenantlit.Tenant{
			Name: name,
			Path: "tenant/" + name,
		}
		if catalog, ok := sub.Dirs["catalog"]; ok {
			if _, ok := catalog.Files["auth.cue"]; ok {
				t.IsLeaf = true
			}
		}
		tenants = append(tenants, t)
	}
	sort.Slice(tenants, func(i, j int) bool { return tenants[i].Name < tenants[j].Name })

	var files []crosstenantlit.SourceFile
	for _, t := range tenants {
		if !t.IsLeaf {
			continue
		}
		root := tenantDir.Dirs[t.Name]
		walkFiles(&root, "tenant/"+t.Name, t.Name, &files)
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return tenants, files
}

func lookupSub(d *spec.Dir, parts ...string) *spec.Dir {
	cur := d
	for _, p := range parts {
		next, ok := cur.Dirs[p]
		if !ok {
			return nil
		}
		cur = &next
	}
	return cur
}

func walkFiles(d *spec.Dir, prefix, tenant string, out *[]crosstenantlit.SourceFile) {
	for name, f := range d.Files {
		if f.Type != "file" {
			continue
		}
		ext := filepath.Ext(name)
		if !allowedExt[ext] {
			continue
		}
		*out = append(*out, crosstenantlit.SourceFile{
			Path:    prefix + "/" + name,
			Tenant:  tenant,
			Content: f.Content,
		})
	}
	for sub, child := range d.Dirs {
		walkFiles(&child, prefix+"/"+sub, tenant, out)
	}
}

// resolveProfiles fills tenants[i].Profiles by CUE-evaluating each
// leaf tenant's catalog/auth.cue against the live cue.mod. Using cue
// eval (not regex) means the spec's notion of "T's owned profiles"
// matches what the k3d / awstofu / aws-ecr generators read at hatch
// time -- so a CUE indirection in auth.cue (defaults, references)
// does not silently shrink the forbidden set. AIDR-00103 closed the
// classifier-vs-evaluator asymmetry the original regex form left open.
func resolveProfiles(workDir string, tenants []crosstenantlit.Tenant) error {
	cctx := cuecontext.New()
	for i := range tenants {
		t := &tenants[i]
		if !t.IsLeaf {
			continue
		}
		authPath := filepath.Join(workDir, "tenant", t.Name, "catalog", "auth.cue")
		insts := load.Instances([]string{authPath}, &load.Config{Dir: workDir})
		if len(insts) == 0 {
			return fmt.Errorf("cue load tenant/%s/catalog/auth.cue: no instances", t.Name)
		}
		if insts[0].Err != nil {
			return fmt.Errorf("cue load tenant/%s/catalog/auth.cue: %w", t.Name, insts[0].Err)
		}
		val := cctx.BuildInstance(insts[0])
		if err := val.Err(); err != nil {
			return fmt.Errorf("cue build tenant/%s auth: %w", t.Name, err)
		}
		authVal := val.LookupPath(cuelang.ParsePath("auth"))
		if !authVal.Exists() {
			continue
		}
		iter, err := authVal.Fields()
		if err != nil {
			return fmt.Errorf("iter tenant/%s auth fields: %w", t.Name, err)
		}
		seen := map[string]bool{}
		var profiles []string
		for iter.Next() {
			fv := iter.Value()
			if fv.Kind() != cuelang.StringKind {
				continue
			}
			s, err := fv.String()
			if err != nil {
				continue
			}
			if seen[s] {
				continue
			}
			seen[s] = true
			profiles = append(profiles, s)
		}
		sort.Strings(profiles)
		t.Profiles = profiles
	}
	return nil
}

// loadGenWrites evaluates the contracts package + per-generator
// contract.cue files + merged lattice and returns the union of
// brick_io.writes paths. Mirrors the brickcollision binary's
// evaluate(): same input set, same overlay strategy.
func loadGenWrites(workDir string, latticeBytes []byte) (map[string]bool, error) {
	cueFiles, err := contractsFileList(workDir)
	if err != nil {
		return nil, err
	}
	latticeVirt := filepath.Join(workDir, "kernel", "spec", "lattice_inproc.json")
	overlay := map[string]load.Source{
		latticeVirt: load.FromBytes(latticeBytes),
	}
	cueFiles = append(cueFiles, latticeVirt)

	cctx := cuecontext.New()
	insts := load.Instances(cueFiles, &load.Config{
		Dir:     workDir,
		Overlay: overlay,
	})
	if len(insts) == 0 {
		return nil, fmt.Errorf("cue load: no instances")
	}
	if insts[0].Err != nil {
		return nil, fmt.Errorf("cue load: %w", insts[0].Err)
	}
	val := cctx.BuildInstance(insts[0])
	if err := val.Err(); err != nil {
		return nil, fmt.Errorf("cue build: %w", err)
	}

	var brickIO map[string]struct {
		Writes []string `json:"writes"`
	}
	if err := val.LookupPath(cuelang.ParsePath("brick_io")).Decode(&brickIO); err != nil {
		return nil, fmt.Errorf("decode brick_io: %w", err)
	}
	out := map[string]bool{}
	for _, io := range brickIO {
		for _, p := range io.Writes {
			out[p] = true
		}
	}
	return out, nil
}

func contractsFileList(workDir string) ([]string, error) {
	var files []string
	files = append(files,
		filepath.Join(workDir, "kernel", "spec", "contracts-schema.cue"),
		filepath.Join(workDir, "kernel", "spec", "known-shared.cue"),
	)
	patterns := []string{
		"kernel/spec/manual-files-*.cue",
		"kernel/spec/convention-contracts*.cue",
		"tenant/library/go/lib/gen/*/contract.cue",
	}
	for _, pat := range patterns {
		matches, err := filepath.Glob(filepath.Join(workDir, pat))
		if err != nil {
			return nil, fmt.Errorf("glob %s: %w", pat, err)
		}
		files = append(files, matches...)
	}
	return files, nil
}
