// Package latticeschema provides the `defn check latticeschema`
// subcommand: AIDR-00061's lattice-schema vet, promoted from the .clj
// `cue vet` shell driver to a self-contained Go subcommand. AIDR-00100
// documents the promotion. The check loads kernel/spec/lattice-schema.cue
// in-process, parses the merged lattice JSON via cue/encoding/json,
// unifies them, and runs val.Validate(cue.Concrete(true)) -- any
// constraint violation in lattice-schema.cue surfaces verbatim.
//
// Exit-code contract (matches the AIDR-00099 #Check schema):
//
//	0 -- clean: lattice JSON conforms to lattice-schema.cue.
//	1 -- violations: schema constraint failures printed on stdout.
//	2 -- usage / IO error: diagnostic on stderr.
package latticeschema

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
	if vetErr, ioErr := vet(workDir); ioErr != nil {
		fmt.Fprintln(os.Stderr, ioErr)
		os.Exit(2)
	} else if vetErr != nil {
		for _, e := range errors.Errors(vetErr) {
			fmt.Println(errors.Details(e, nil))
		}
		os.Exit(1)
	}
	fmt.Println("ok")
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

// vet returns (validationErr, ioErr). See //go/cmd/check/contracts for
// the same shape.
func vet(workDir string) (error, error) {
	schemaPath := filepath.Join(workDir, "kernel", "spec", "lattice-schema.cue")
	latticeBytes, err := spec.MergeShards(filepath.Join(workDir, "var", "lattice"))
	if err != nil {
		return nil, fmt.Errorf("merge lattice shards: %w", err)
	}

	cctx := cuecontext.New()
	insts := load.Instances([]string{schemaPath}, &load.Config{Dir: workDir})
	if len(insts) == 0 {
		return nil, fmt.Errorf("cue load: no instances")
	}
	if insts[0].Err != nil {
		return nil, fmt.Errorf("cue load: %w", insts[0].Err)
	}
	schemaVal := cctx.BuildInstance(insts[0])
	if err := schemaVal.Err(); err != nil {
		return err, nil
	}

	expr, err := cuejson.Extract("lattice.json", latticeBytes)
	if err != nil {
		return nil, fmt.Errorf("parse lattice JSON: %w", err)
	}
	latticeVal := cctx.BuildExpr(expr)
	if err := latticeVal.Err(); err != nil {
		return nil, fmt.Errorf("build lattice value: %w", err)
	}

	unified := schemaVal.Unify(latticeVal)
	if err := unified.Err(); err != nil {
		return err, nil
	}
	if err := unified.Validate(cue.Concrete(true)); err != nil {
		return err, nil
	}
	return nil, nil
}
