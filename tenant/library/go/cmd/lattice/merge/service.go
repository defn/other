// Package merge provides the `defn lattice merge` subcommand: a thin
// wrapper around //go/lib/spec.MergeShards that reads a shard
// directory and emits the canonical lattice JSON (stdout by default,
// or to a path passed via --out). AIDR-00100 documents the promotion
// of the retired `lmerge` binary to this user-facing leaf.
package merge

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/defn/other/m/tenant/library/go/lib/spec"
	"github.com/spf13/cobra"
)

type Config struct {
	ShardDir string
	Out      string
}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	shardDir, err := resolveShardDir(cfg.ShardDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	merged, err := spec.MergeShards(shardDir)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if cfg.Out == "" {
		if _, err := os.Stdout.Write(merged); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return nil
	}
	if err := os.WriteFile(cfg.Out, merged, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	return nil
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(cmd *cobra.Command, args []string) Config {
	out, _ := cmd.Flags().GetString("out")
	cfg := Config{Out: out}
	if len(args) > 0 {
		cfg.ShardDir = args[0]
	}
	return cfg
}

func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().String("out", "", "output path for merged JSON (default: stdout)")
}

// resolveShardDir returns an absolute shard dir. If override is empty,
// walk up from cwd to find cue.mod/module.cue and append the canonical
// lattice subdir. Mirrors //go/cmd/check/brickcollision's workdir
// discovery so interactive `defn lattice merge` from anywhere in the
// workspace just works.
func resolveShardDir(override string) (string, error) {
	if override != "" {
		abs, err := filepath.Abs(override)
		if err != nil {
			return "", fmt.Errorf("resolve shard dir: %w", err)
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
			return filepath.Join(d, "kernel", "spec", "lattice"), nil
		}
		parent := filepath.Dir(d)
		if parent == d {
			return "", fmt.Errorf("cue.mod/module.cue not found above %s", cwd)
		}
		d = parent
	}
}
