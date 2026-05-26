// Package brickcollision provides the `defn check brickcollision`
// subcommand: AIDR-00098's pairwise-write-intersection check, promoted
// from an internal Go binary to a user-facing CLI. AIDR-00099 documents
// the promotion. The check internalizes the CUE evaluation that the
// internal binary used to receive as a JSON dump -- it reads the
// kernel/spec contracts package + per-generator contract.cue files +
// merged lattice in-process, then calls
// //tenant/library/go/lib/spec/brickcollision.Check.
//
// Exit-code contract (matches the AIDR-00099 #Check schema):
//
//	0 -- clean: no non-ancestor brick pair shares a write path.
//	1 -- violations: one line per Collision.Format() on stdout.
//	2 -- usage / IO error: diagnostic on stderr.
//
// Workdir discovery walks up from the current directory looking for
// cue.mod/module.cue. The --workdir flag overrides the discovery for
// callers (e.g. Bazel sh_tests) whose cwd is not inside the workspace.
package brickcollision

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	cuelang "cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
	"github.com/defn/other/m/tenant/library/go/lib/spec"
	"github.com/defn/other/m/tenant/library/go/lib/spec/brickcollision"
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
	collisions, err := evaluate(workDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if len(collisions) == 0 {
		fmt.Println("ok")
		return nil
	}
	for _, c := range collisions {
		fmt.Println(c.Format())
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

// resolveWorkDir returns an absolute workspace root. If override is
// non-empty it is used as-is; otherwise we walk up from the current
// directory looking for cue.mod/module.cue.
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

// evaluate loads the contracts package + per-generator contract.cue
// files + merged lattice and runs brickcollision.Check.
func evaluate(workDir string) ([]brickcollision.Collision, error) {
	cueFiles, err := contractsFileList(workDir)
	if err != nil {
		return nil, err
	}
	latticeBytes, err := spec.MergeShards(filepath.Join(workDir, "var", "lattice"))
	if err != nil {
		return nil, fmt.Errorf("merge lattice shards: %w", err)
	}

	// Inject the lattice JSON as a data file via load overlay. The
	// virtual path lives inside workDir so it shares the cue.mod/
	// module declaration with the contracts files. CUE classifies the
	// .json suffix as a data file and unifies it into the same
	// instance as the contracts package.
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

	var bricks map[string]brickcollision.Brick
	if err := val.LookupPath(cuelang.ParsePath("bricks")).Decode(&bricks); err != nil {
		return nil, fmt.Errorf("decode bricks: %w", err)
	}
	var brickIO map[string]brickcollision.BrickIO
	if err := val.LookupPath(cuelang.ParsePath("brick_io")).Decode(&brickIO); err != nil {
		return nil, fmt.Errorf("decode brick_io: %w", err)
	}
	return brickcollision.Check(bricks, brickIO), nil
}

// contractsFileList enumerates the .cue inputs that the CUE evaluation
// unifies. Mirrors //kernel/spec:brick_collision_vet's data deps:
// contracts-schema + known-shared + manual-files shards +
// convention-contracts shards + every generator's contract.cue.
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
