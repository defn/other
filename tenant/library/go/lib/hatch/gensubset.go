package hatch

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
	cuejson "cuelang.org/go/encoding/json"
	"github.com/defn/other/m/tenant/library/go/lib/spec"
)

// LoadGeneratorClaims returns a map from contract name to the list
// of concrete output paths the generator claims, as resolved against
// the workspace's lattice JSON. AIDR-00132 step 6 calls this "the
// lattice's generators.<name>.paths index" -- the contracts ARE the
// index, but Pattern-A generators (catalog comprehensions over
// lattice tree / catalog.bricks) only yield concrete paths when
// unified against real lattice data. So this loads the same input
// set as `defn check contracts`: contracts-schema, every per-generator
// contract.cue, every convention-contract, every manual-files shard,
// and the merged lattice JSON.
//
// We do NOT call .Validate() -- the goal is to read concrete `paths`
// values, not to run the full vet (orphans, missingClaims, etc.).
// A vet failure elsewhere should not deny per-brick hatch the gen
// subset it can compute. The merge-boundary `defn check contracts`
// is the gate for vet correctness.
//
// If the lattice has not been generated yet (no _index.json), the
// loader falls back to placeholder mode: contracts unify against
// `tree: _` / `bricks: _` from the schema and Pattern-A paths
// resolve to empty lists. That mode is enough for tests / fresh
// checkouts; production flows always run hatch first.
func LoadGeneratorClaims(workDir string) (map[string][]string, error) {
	contractFiles, err := contractsFileList(workDir)
	if err != nil {
		return nil, err
	}
	cctx := cuecontext.New()
	insts := load.Instances(contractFiles, &load.Config{Dir: workDir})
	if len(insts) == 0 {
		return nil, fmt.Errorf("cue load: no instances")
	}
	if insts[0].Err != nil {
		return nil, fmt.Errorf("cue load contracts: %w", insts[0].Err)
	}
	schemaVal := cctx.BuildInstance(insts[0])
	if err := schemaVal.Err(); err != nil {
		return nil, fmt.Errorf("build contracts: %w", err)
	}

	unified := schemaVal
	latticeBytes, lerr := spec.MergeShards(filepath.Join(workDir, "kernel", "spec", "lattice"))
	if lerr == nil {
		expr, eerr := cuejson.Extract("lattice.json", latticeBytes)
		if eerr != nil {
			return nil, fmt.Errorf("parse lattice JSON: %w", eerr)
		}
		latticeVal := cctx.BuildExpr(expr)
		if err := latticeVal.Err(); err != nil {
			return nil, fmt.Errorf("build lattice value: %w", err)
		}
		unified = schemaVal.Unify(latticeVal)
		// Unify errors at the schema-assertion level (orphans,
		// missingClaims, etc.) do not prevent extracting concrete
		// `generators[*].paths` -- those evaluate independently.
		// Only the merge-boundary `defn check contracts` is the
		// gate for vet correctness; per-brick hatch needs path
		// data even when the workspace is mid-migration.
		_ = unified.Err()
	}

	gens := unified.LookupPath(cue.ParsePath("generators"))
	if !gens.Exists() {
		return map[string][]string{}, nil
	}

	out := make(map[string][]string)
	it, err := gens.Fields()
	if err != nil {
		return nil, fmt.Errorf("iterate generators: %w", err)
	}
	for it.Next() {
		name := it.Selector().String()
		var paths []string
		if pv := it.Value().LookupPath(cue.ParsePath("paths")); pv.Exists() {
			_ = pv.Decode(&paths)
		}
		out[name] = paths
	}
	return out, nil
}

// contractsFileList mirrors go/cmd/check/contracts.contractsFileList:
// the .cue input set every contract evaluation must include.
// Duplicated rather than imported because go/cmd/check/contracts
// already depends on this package's siblings via gen.Context loaders;
// inlining keeps the dep graph one-way (hatch -> spec, never back).
func contractsFileList(workDir string) ([]string, error) {
	files := []string{
		filepath.Join(workDir, "kernel", "spec", "contracts-schema.cue"),
		filepath.Join(workDir, "kernel", "spec", "known-shared.cue"),
	}
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

// SelectGenSubset returns the contract names whose claimed paths
// fall (entirely or partially) under brickPath. The returned set is
// the gen-subset that AIDR-00132 step 6 dispatches per brick. The
// list is sorted for deterministic execution order.
//
// "Falls under" means: the path equals brickPath, or starts with
// brickPath+"/". Empty brickPath matches every path (the root
// brick covers the whole workspace, but the root is not a normal
// dispatch target -- the coordinator filters it out before calling
// in here).
func SelectGenSubset(claims map[string][]string, brickPath string) []string {
	if len(claims) == 0 {
		return nil
	}
	prefix := brickPath
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}
	var out []string
	for name, paths := range claims {
		for _, p := range paths {
			if pathUnderBrick(p, brickPath, prefix) {
				out = append(out, name)
				break
			}
		}
	}
	sort.Strings(out)
	return out
}

func pathUnderBrick(p, brickPath, brickPrefix string) bool {
	if brickPath == "" {
		return true
	}
	if p == brickPath {
		return true
	}
	return strings.HasPrefix(p, brickPrefix)
}

// PathsOutsideBrick returns the subset of `paths` that fall outside
// brickPath. Used by the dirty-write detector: a generator that
// writes any path not under brickPath has violated the per-brick
// contract, and the result must surface as `status: "dirty"` per
// AIDR-00132 step 9.
func PathsOutsideBrick(paths []string, brickPath string) []string {
	prefix := brickPath
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}
	var out []string
	for _, p := range paths {
		if !pathUnderBrick(p, brickPath, prefix) {
			out = append(out, p)
		}
	}
	return out
}
