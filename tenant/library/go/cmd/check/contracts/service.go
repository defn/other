// Package contracts provides the `defn check contracts` subcommand:
// AIDR-00062's generator-contracts vet (orphans, missingClaims,
// manualClaimed, unannouncedShared), promoted from the .clj
// `cue vet` shell driver to a self-contained Go subcommand. AIDR-00100
// documents the promotion and the internalized cuelang.org/go/cue
// vet pipeline. The check unifies kernel/spec/contracts-schema.cue,
// known-shared, every manual-files / convention-contracts shard, and
// every per-generator contract.cue, then unifies the result with the
// merged lattice JSON parsed via cue/encoding/json. Constraint
// failures listed in contracts-schema.cue (orphans: [],
// missingClaims: [], ...) surface verbatim under
// val.Validate(cue.Concrete(true)).
//
// Exit-code contract (matches the AIDR-00099 #Check schema):
//
//	0 -- clean: contracts unify cleanly under cue.Concrete validation.
//	1 -- violations: validation errors printed on stdout.
//	2 -- usage / IO error: diagnostic on stderr.
package contracts

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/load"
	cuejson "cuelang.org/go/encoding/json"
	"github.com/defn/other/m/tenant/library/go/lib/spec"
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
	vetErr, diag, ioErr := vet(workDir)
	if ioErr != nil {
		fmt.Fprintln(os.Stderr, ioErr)
		os.Exit(2)
	}
	if vetErr != nil {
		// The structured diagnostic comes first -- it names the
		// actual offending paths, which CUE's "incompatible list
		// lengths" error does not. Fall through to the raw CUE
		// error afterward for the schema:line:col context.
		printDiagnostic(diag)
		for _, e := range errors.Errors(vetErr) {
			fmt.Println(errors.Details(e, nil))
		}
		os.Exit(1)
	}
	fmt.Println("ok")
	return nil
}

// vetDiagnostic captures the four offending-path lists extracted
// from the schema's hidden `_<field>Out` mirrors. Populated whether
// or not the public assertions fail -- a non-empty list means the
// assertion will fail; a non-empty list named here is exactly the
// fix-list the operator needs.
type vetDiagnostic struct {
	Orphans           []string
	MissingClaims     []string
	UnannouncedShared []string
	ManualClaimed     []string
}

func printDiagnostic(d vetDiagnostic) {
	type item struct {
		name  string
		paths []string
		hint  string
	}
	items := []item{
		{"orphans", d.Orphans,
			"file exists in the lattice but is neither claimed by any generator's contract.cue nor listed in a kernel/spec/manual-files-*.cue shard"},
		{"missingClaims", d.MissingClaims,
			"a generator's contract.cue claims a path that doesn't exist in the lattice (run hatch to refresh, or fix the contract)"},
		{"unannouncedShared", d.UnannouncedShared,
			"two or more generators claim the same path; add it to kernel/spec/known-shared.cue with a reason and a consolidation plan"},
		{"manualClaimed", d.ManualClaimed,
			"a path is in BOTH a generator's claim list AND a kernel/spec/manual-files-*.cue shard; remove from one (a file is either generated or hand-edited, never both)"},
	}
	for _, it := range items {
		if len(it.paths) == 0 {
			continue
		}
		fmt.Printf("\nvet failure: %s (%d)\n", it.name, len(it.paths))
		fmt.Printf("  %s\n\n", it.hint)
		for _, p := range it.paths {
			fmt.Printf("  - %s\n", p)
		}
	}
	fmt.Println()
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

// vet returns (validationErr, diagnostic, ioErr). validationErr
// non-nil means the CUE constraints failed (exit 1). ioErr non-nil
// means we couldn't get to the validation step at all (exit 2).
// The diagnostic carries the four offending-path lists pulled from
// the schema's hidden `_<field>Out` mirrors -- populated unconditionally
// so the caller can print structured failure context even when CUE's
// own error elides the contents (e.g. "incompatible list lengths").
func vet(workDir string) (error, vetDiagnostic, error) {
	var diag vetDiagnostic
	cueFiles, err := contractsFileList(workDir)
	if err != nil {
		return nil, diag, err
	}
	latticeBytes, err := spec.MergeShards(filepath.Join(workDir, "var", "lattice"))
	if err != nil {
		return nil, diag, fmt.Errorf("merge lattice shards: %w", err)
	}

	cctx := cuecontext.New()
	insts := load.Instances(cueFiles, &load.Config{Dir: workDir})
	if len(insts) == 0 {
		return nil, diag, fmt.Errorf("cue load: no instances")
	}
	if insts[0].Err != nil {
		return nil, diag, fmt.Errorf("cue load: %w", insts[0].Err)
	}
	schemaVal := cctx.BuildInstance(insts[0])
	if err := schemaVal.Err(); err != nil {
		return err, diag, nil
	}

	expr, err := cuejson.Extract("lattice.json", latticeBytes)
	if err != nil {
		return nil, diag, fmt.Errorf("parse lattice JSON: %w", err)
	}
	latticeVal := cctx.BuildExpr(expr)
	if err := latticeVal.Err(); err != nil {
		return nil, diag, fmt.Errorf("build lattice value: %w", err)
	}

	unified := schemaVal.Unify(latticeVal)
	if err := unified.Err(); err != nil {
		diag = extractDiagnostic(unified)
		return err, diag, nil
	}
	if err := unified.Validate(cue.Concrete(true)); err != nil {
		diag = extractDiagnostic(unified)
		return err, diag, nil
	}
	return nil, diag, nil
}

// extractDiagnostic reads the schema's hidden `_<field>Out` mirrors
// and decodes them into the diagnostic struct. Each mirror holds
// the same comprehension as its public twin but without the
// `: []` assertion, so its concrete value survives unification
// even when the public field is bottom.
func extractDiagnostic(unified cue.Value) vetDiagnostic {
	var d vetDiagnostic
	// Hidden fields (those starting with `_`) are scoped to their
	// declaring package. cue.Value.Fields(cue.Hidden(true)) walks
	// them; the selector iteration matches by name regardless of
	// the package qualifier, which Hid() requires when constructing
	// a path. Iteration is robust; LookupPath+Hid was brittle here.
	mirrors := map[string]*[]string{
		"_orphansOut":           &d.Orphans,
		"_missingClaimsOut":     &d.MissingClaims,
		"_unannouncedSharedOut": &d.UnannouncedShared,
		"_manualClaimedOut":     &d.ManualClaimed,
	}
	it, err := unified.Fields(cue.Hidden(true), cue.Optional(true), cue.Definitions(true))
	if err != nil {
		return d
	}
	for it.Next() {
		name := it.Selector().String()
		dst, ok := mirrors[name]
		if !ok {
			continue
		}
		v := it.Value()
		if !v.Exists() || v.Err() != nil {
			continue
		}
		_ = v.Decode(dst)
	}
	return d
}

// contractsFileList enumerates the .cue inputs that the CUE evaluation
// unifies. Mirrors //kernel/spec:contracts_vet's data deps:
// contracts-schema + known-shared + manual-files shards +
// convention-contracts shards + every generator's contract.cue.
// Per AIDR-00138 D5.2, tenant-side `package contracts` shards under
// tenant/<t>/spec/*.cue are unified alongside kernel/spec ones so
// tenants can own their own hand-written-file allowlists.
func contractsFileList(workDir string) ([]string, error) {
	var files []string
	files = append(files,
		filepath.Join(workDir, "kernel", "spec", "contracts-schema.cue"),
		filepath.Join(workDir, "kernel", "spec", "known-shared.cue"),
	)
	patterns := []string{
		"kernel/spec/manual-files-*.cue",
		"kernel/spec/convention-contracts*.cue",
		"tenant/*/spec/manual-files-*.cue",
		"tenant/*/spec/convention-contracts*.cue",
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
