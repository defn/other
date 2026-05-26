// Package golib generates Go library BUILD.bazel files from the catalog.
package golib

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

const localModPrefix = "github.com/defn/other/m/"

// Run generates <path>/BUILD.bazel for each go_lib_bricks entry.
func Run(ctx *gen.Context) error {
	libs := ctx.CatalogQuery("go_lib_bricks")

	type entry struct {
		name string
		path string
	}
	var entries []entry
	if err := gen.IterMap(libs, func(_ string, v cue.Value) error {
		p, _ := gen.DecodeString(v, "path")
		name := p[strings.LastIndex(p, "/")+1:]
		entries = append(entries, entry{name: name, path: p})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate go_lib_bricks: %w", err)
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].path < entries[j].path })

	// Build module map once for auto-deps resolution.
	modules, err := buildModuleMap(ctx.WorkDir)
	if err != nil {
		return fmt.Errorf("build module map: %w", err)
	}

	// Accumulate per-brick in-brick file lists for the contract.cue
	// generated inputs block. The contract concatenates these into its
	// claimed paths so new in-brick files don't need a
	// spec/manual-files.cue edit. See AIDR-00093 (inputs.cue fold).
	inputs := make(map[string][]string, len(entries))

	for _, e := range entries {
		srcs, err := goFiles(filepath.Join(ctx.WorkDir, e.path))
		if err != nil {
			return err
		}
		srcsJSON, _ := json.Marshal(srcs)

		// Auto-generate deps.cue if missing.
		depsPath := filepath.Join(ctx.WorkDir, e.path, "deps.cue")
		if !fileExists(depsPath) && len(srcs) > 0 {
			if err := autoDeps(ctx.WorkDir, e.path, modules); err != nil {
				return fmt.Errorf("auto-deps %s: %w", e.path, err)
			}
		}

		depsJSON, err := ReadDepsJSON(ctx, e.path)
		if err != nil {
			return err
		}

		hasDeps := "false"
		if fileExists(filepath.Join(ctx.WorkDir, e.path, "deps.cue")) {
			hasDeps = "true"
		}

		hasContract := "false"
		if fileExists(filepath.Join(ctx.WorkDir, e.path, "contract.cue")) {
			hasContract = "true"
		}

		embedsrcs, err := detectEmbedSrcs(filepath.Join(ctx.WorkDir, e.path), srcs)
		if err != nil {
			return err
		}
		embedsrcsJSON := []byte("[]")
		if len(embedsrcs) > 0 {
			embedsrcsJSON, _ = json.Marshal(embedsrcs)
		}

		// Detect test files. Tests are only generated when the brick
		// has _test.go files AND a test_deps.cue file (opt-in signal).
		// This avoids generating broken go_test rules for vendored
		// code with undeclared test dependencies.
		// allTestSrcs is the full _test.go set for sidecar claiming,
		// independent of whether a go_test rule will be generated.
		allTestSrcs, err := goTestFiles(filepath.Join(ctx.WorkDir, e.path))
		if err != nil {
			return err
		}
		testSrcs := allTestSrcs
		hasTestDeps := fileExists(filepath.Join(ctx.WorkDir, e.path, "test_deps.cue"))
		if !hasTestDeps {
			testSrcs = nil // skip test generation without opt-in
		}
		testSrcsJSON := []byte("[]")
		if len(testSrcs) > 0 {
			testSrcsJSON, _ = json.Marshal(testSrcs)
		}
		testDepsJSON := []byte("[]")
		if len(testSrcs) > 0 && hasTestDeps {
			// Auto-populate test_deps.cue if it's empty.
			tdJSON, err := readTestDepsJSON(ctx, e.path)
			if err != nil {
				return err
			}
			if tdJSON == "[]" {
				// test_deps.cue exists but is empty -- auto-discover.
				if err := autoTestDeps(ctx.WorkDir, e.path, modules, depsJSON); err != nil {
					return fmt.Errorf("auto-test-deps %s: %w", e.path, err)
				}
				tdJSON, err = readTestDepsJSON(ctx, e.path)
				if err != nil {
					return err
				}
			}
			testDepsJSON = []byte(tdJSON)
		}

		testLocal := "false"
		testDataJSON := []byte("[]")
		if hasTestDeps {
			testLocal = readTestLocal(ctx, e.path)
			td, err := readTestDataJSON(ctx, e.path)
			if err != nil {
				return err
			}
			testDataJSON = []byte(td)
		}

		if err := ctx.StampFromCUE(
			"kernel/interface/go-lib/templates.cue", e.path,
			map[string]string{
				"name":         e.name,
				"importpath":   "github.com/defn/other/m/" + e.path,
				"srcs":         string(srcsJSON),
				"deps":         depsJSON,
				"has_deps":     hasDeps,
				"has_contract": hasContract,
				"embedsrcs":    string(embedsrcsJSON),
				"test_srcs":    string(testSrcsJSON),
				"test_deps":    string(testDepsJSON),
				"test_data":    string(testDataJSON),
				"test_local":   testLocal,
			},
			[]gen.StampFile{{Field: "build_bazel", Filename: "BUILD.bazel"}},
		); err != nil {
			return fmt.Errorf("stamp %s: %w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %s/BUILD.bazel", e.path))

		// Record the in-brick files this brick owns. The generator writes
		// BUILD.bazel itself (claimed via the static paths list); the rest
		// are hand-authored inputs that the contract should claim so they
		// don't need an entry in spec/manual-files.cue.
		var files []string
		files = append(files, srcs...)
		files = append(files, allTestSrcs...)
		for _, f := range []string{"deps.cue", "test_deps.cue", "contract.cue"} {
			if fileExists(filepath.Join(ctx.WorkDir, e.path, f)) {
				files = append(files, f)
			}
		}
		sort.Strings(files)
		inputs[e.path] = files
	}

	if err := WriteInputsBlock(ctx, "tenant/library/go/lib/gen/golib", "golib", "_golib_inputs", inputs); err != nil {
		return fmt.Errorf("write inputs block: %w", err)
	}
	return nil
}

// WriteInputsBlock writes the per-brick inputs map into a hidden field
// inside <generatorDir>/contract.cue, replacing a marker-delimited region
// at the end of the file. This is the write side of Pattern B in the
// auto-claim taxonomy (see AIDR-00066 and the "How to declare `paths`"
// header in spec/contracts-schema.cue); AIDR-00093 folded the previous
// separate inputs.cue sidecar into the sibling contract.cue.
//
// Why this exists: for generators whose per-brick file set VARIES (Go
// sources per brick, tofu lock file presence per infra dir, chart tarball
// name per app version), the contract cannot enumerate paths statically.
// The generator already walks each brick at stamp time, so it emits what
// it saw here; contract.cue's hand-written part does
//
//	paths: list.Concat([...static roster..., [for b, fs in _<tag>_inputs for f in fs {"\(b)/\(f)"}]])
//
// and contracts_vet treats the listed files as claimed, so they don't need
// entries in spec/manual-files.cue.
//
// The marker pair
//
//	// === BEGIN GENERATED: <field> ===
//	...generated content...
//	// === END GENERATED: <field> ===
//
// delimits the generator-managed region. Hand-written content lives above
// the BEGIN marker. If the markers are absent (first migration), the
// block is appended at the end of the file.
//
// Idempotence: uses gen.WriteIfChanged so a no-op run preserves mtime,
// which keeps Bazel's analysis cache warm (AIDR-00058).
//
//	generatorDir: the generator's own brick (e.g. "tenant/library/go/lib/gen/gocmd").
//	generatorTag: human label used in the generated header comment
//	              (e.g. "gocmd").
//	field:        the CUE hidden-field name read by the contract.cue
//	              (e.g. "_gocmd_inputs" -- the leading underscore makes it
//	              a CUE hidden field so it never leaks into the lattice).
//	inputs:       brick path -> sorted list of file names. Callers should
//	              use CollectBrickInputs (below) to produce this map so
//	              the file-set conventions stay uniform across generators.
func WriteInputsBlock(ctx *gen.Context, generatorDir, generatorTag, field string, inputs map[string][]string) error {
	beginMarker := fmt.Sprintf("// === BEGIN GENERATED: %s ===", field)
	endMarker := fmt.Sprintf("// === END GENERATED: %s ===", field)

	keys := make([]string, 0, len(inputs))
	for k := range inputs {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// Reject input strings containing the marker literal -- a brick path
	// or filename embedding the marker text would survive %q quoting and
	// trip the next splice's strings.Index. Per AIDR-00094.
	for _, k := range keys {
		if strings.Contains(k, beginMarker) || strings.Contains(k, endMarker) {
			return fmt.Errorf("brick path %q contains marker literal for %s", k, field)
		}
		for _, f := range inputs[k] {
			if strings.Contains(f, beginMarker) || strings.Contains(f, endMarker) {
				return fmt.Errorf("file name %q under %q contains marker literal for %s", f, k, field)
			}
		}
	}

	var block strings.Builder
	block.WriteString(beginMarker)
	block.WriteString("\n")
	fmt.Fprintf(&block, "// Per-brick in-brick file roster emitted by %s.\n", generatorTag)
	block.WriteString("// Rewritten by `mise run gen`. Do not hand-edit this section.\n")
	block.WriteString("// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.\n\n")
	fmt.Fprintf(&block, "%s: [string]: [...string]\n\n", field)
	if len(keys) == 0 {
		// Empty map: cue fmt insists on `{}` (no newline before close)
		// when there are no fields. Pattern B fold per AIDR-00093.
		fmt.Fprintf(&block, "%s: {}\n\n", field)
	} else {
		fmt.Fprintf(&block, "%s: {\n", field)
		for _, k := range keys {
			block.WriteString("\t")
			block.WriteString(fmt.Sprintf("%q", k))
			block.WriteString(": [")
			for i, f := range inputs[k] {
				if i > 0 {
					block.WriteString(", ")
				}
				block.WriteString(fmt.Sprintf("%q", f))
			}
			block.WriteString("]\n")
		}
		block.WriteString("}\n\n")
	}
	block.WriteString(endMarker)
	block.WriteString("\n")

	rel := filepath.Join(generatorDir, "contract.cue")
	contractPath := filepath.Join(ctx.WorkDir, rel)
	existing, err := os.ReadFile(contractPath)
	if err != nil {
		return fmt.Errorf("read %s: %w", rel, err)
	}
	src := string(existing)
	// Marker uniqueness: refuse to splice if either marker appears more
	// than once. The helper produces exactly one pair; >1 means
	// hand-edit drift. Per AIDR-00094 finding #8.
	if n := strings.Count(src, beginMarker); n > 1 {
		return fmt.Errorf("%s: BEGIN marker for %s appears %d times (expect 0 or 1)", rel, field, n)
	}
	if n := strings.Count(src, endMarker); n > 1 {
		return fmt.Errorf("%s: END marker for %s appears %d times (expect 0 or 1)", rel, field, n)
	}
	var updated string
	if i := strings.Index(src, beginMarker); i >= 0 {
		// Anchor the END search after the BEGIN match so a stray
		// marker-shaped string earlier in the file (e.g. doc-comment
		// example) cannot mis-position the splice. Per AIDR-00094.
		searchFrom := i + len(beginMarker)
		offset := strings.Index(src[searchFrom:], endMarker)
		if offset < 0 {
			return fmt.Errorf("%s: BEGIN marker present but END marker missing for %s", rel, field)
		}
		j := searchFrom + offset
		endLine := j + len(endMarker)
		// LF-only; the repo is Linux-only per CLAUDE.md.
		if endLine < len(src) && src[endLine] == '\n' {
			endLine++
		}
		updated = src[:i] + block.String() + src[endLine:]
	} else {
		// First-time migration: append the block separated from existing
		// content by exactly one blank line.
		if len(src) == 0 {
			updated = block.String()
		} else {
			updated = strings.TrimRight(src, "\n") + "\n\n" + block.String()
		}
	}

	if _, err := gen.WriteIfChanged(contractPath, []byte(updated), 0o644); err != nil {
		return err
	}
	ctx.LogOK("updated " + rel + " (" + field + ")")
	return nil
}

// CollectBrickInputs returns the sorted list of in-brick files a brick owns:
// every *.go file plus any of deps.cue / test_deps.cue / contract.cue
// that exist, filtered by `exclude` (e.g. ["command.go"] for go-cmd
// bricks whose command.go is a generator output). Shared by all
// brick-level Go generators so their input rosters are assembled
// identically.
//
// Pair with WriteInputsBlock above: callers typically accumulate a
// map[brickPath][]string during their main loop, calling CollectBrickInputs
// per brick, then flush with one WriteInputsBlock at the end.
//
// Exclude list: anything the generator WRITES itself (command.go for
// go-cmd bricks, gen-app.cue for kustomize apps). Those are claimed via
// the static paths list; putting them in the inputs block too would
// create multi-writer collisions inside the same generator.
func CollectBrickInputs(workDir, brickPath string, exclude ...string) ([]string, error) {
	dir := filepath.Join(workDir, brickPath)
	excl := make(map[string]bool, len(exclude))
	for _, f := range exclude {
		excl[f] = true
	}
	var files []string
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", brickPath, err)
	}
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".go") || excl[e.Name()] {
			continue
		}
		files = append(files, e.Name())
	}
	for _, f := range []string{"deps.cue", "test_deps.cue", "contract.cue"} {
		if excl[f] {
			continue
		}
		if fileExists(filepath.Join(dir, f)) {
			files = append(files, f)
		}
	}
	sort.Strings(files)
	return files, nil
}

func goFiles(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", dir, err)
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".go") && !strings.HasSuffix(e.Name(), "_test.go") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

func goTestFiles(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", dir, err)
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), "_test.go") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

// autoTestDeps generates test_deps.cue from go list -json -test output.
// It extracts test-only imports that aren't already in the library's deps.
func autoTestDeps(workDir, pkgPath string, modules []string, libDepsJSON string) error {
	var out bytes.Buffer
	if err := runner.Run(context.Background(), runner.Opts{
		Args:   []string{"go", "list", "-json", "-test", "./" + pkgPath},
		Dir:    workDir,
		Stdout: &out,
	}); err != nil {
		return fmt.Errorf("go list -test %s: %w", pkgPath, err)
	}

	// Collect TestImports and XTestImports from all JSON objects.
	// TestImports: internal test files (same package).
	// XTestImports: external test files (package foo_test).
	var testImports []string
	dec := json.NewDecoder(&out)
	for dec.More() {
		var pkg struct {
			TestImports  []string `json:"TestImports"`
			XTestImports []string `json:"XTestImports"`
		}
		if err := dec.Decode(&pkg); err != nil {
			break
		}
		for _, imp := range pkg.TestImports {
			if !isStdlib(imp) {
				testImports = append(testImports, imp)
			}
		}
		for _, imp := range pkg.XTestImports {
			if !isStdlib(imp) {
				testImports = append(testImports, imp)
			}
		}
	}

	// Convert to labels.
	var testLabels []string
	for _, imp := range testImports {
		if label, ok := importToLabel(imp, modules); ok {
			testLabels = append(testLabels, label)
		}
	}

	// Remove deps already in the library.
	libDeps := map[string]bool{}
	var allDeps []string
	if err := json.Unmarshal([]byte(libDepsJSON), &allDeps); err == nil {
		for _, d := range allDeps {
			// Normalize: //pkg -> //pkg:last for comparison.
			if !strings.Contains(d, ":") {
				last := d[strings.LastIndex(d, "/")+1:]
				d = d + ":" + last
			}
			libDeps[d] = true
		}
	}
	// Also exclude self-reference (the package being tested, embedded via embed).
	selfLabel := "//" + pkgPath + ":" + pkgPath[strings.LastIndex(pkgPath, "/")+1:]
	libDeps[selfLabel] = true

	seen := map[string]bool{}
	var extra []string
	for _, l := range testLabels {
		if !libDeps[l] && !seen[l] {
			extra = append(extra, l)
			seen[l] = true
		}
	}
	sort.Strings(extra)

	// Preserve hand-edited fields after the test_deps block.
	// Everything after the closing "]" of test_deps is preserved (local, test_data, etc.)
	tdPath := filepath.Join(workDir, pkgPath, "test_deps.cue")
	var suffix string
	if data, err := os.ReadFile(tdPath); err == nil {
		content := string(data)
		// Find end of test_deps block -- either "test_deps: []" line or closing "]"
		lines := strings.Split(content, "\n")
		pastTestDeps := false
		var suffixLines []string
		for _, line := range lines {
			trimmed := strings.TrimSpace(line)
			if pastTestDeps {
				suffixLines = append(suffixLines, line)
			} else if trimmed == "test_deps: []" || (trimmed == "]" && strings.Contains(content, "test_deps: [")) {
				pastTestDeps = true
			}
		}
		// Keep non-empty suffix lines.
		s := strings.TrimSpace(strings.Join(suffixLines, "\n"))
		if s != "" {
			suffix = "\n" + s + "\n"
		}
	}

	// Write test_deps.cue.
	var buf strings.Builder
	buf.WriteString("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\npackage test_deps\n\n")
	if len(extra) == 0 {
		buf.WriteString("test_deps: []\n")
	} else {
		buf.WriteString("test_deps: [\n")
		for _, l := range extra {
			buf.WriteString("\t\"" + l + "\",\n")
		}
		buf.WriteString("]\n")
	}
	buf.WriteString(suffix)
	_, err := gen.WriteIfChanged(tdPath, []byte(buf.String()), 0o644)
	return err
}

// readTestDepsJSON reads test_deps from test_deps.cue as a JSON array string.
func readTestDepsJSON(ctx *gen.Context, pkgPath string) (string, error) {
	relPath := filepath.Join(pkgPath, "test_deps.cue")
	absPath := filepath.Join(ctx.WorkDir, relPath)
	if !fileExists(absPath) {
		return "[]", nil
	}
	val, err := ctx.LoadCUEPackage(relPath, nil)
	if err != nil {
		return "", fmt.Errorf("load test_deps.cue in %s: %w", pkgPath, err)
	}
	depsVal := val.LookupPath(cue.ParsePath("test_deps"))
	deps := []string{}
	iter, err := depsVal.List()
	if err != nil {
		return "", fmt.Errorf("list test_deps in %s: %w", pkgPath, err)
	}
	for iter.Next() {
		s, _ := iter.Value().String()
		deps = append(deps, s)
	}
	b, _ := json.Marshal(deps)
	return string(b), nil
}

// readTestDataJSON reads test_data from test_deps.cue as a JSON array string.
func readTestDataJSON(ctx *gen.Context, pkgPath string) (string, error) {
	relPath := filepath.Join(pkgPath, "test_deps.cue")
	absPath := filepath.Join(ctx.WorkDir, relPath)
	if !fileExists(absPath) {
		return "[]", nil
	}
	val, err := ctx.LoadCUEPackage(relPath, nil)
	if err != nil {
		return "[]", nil
	}
	dataVal := val.LookupPath(cue.ParsePath("test_data"))
	if dataVal.Err() != nil {
		return "[]", nil
	}
	var data []string
	iter, err := dataVal.List()
	if err != nil {
		return "[]", nil
	}
	for iter.Next() {
		s, _ := iter.Value().String()
		data = append(data, s)
	}
	if len(data) == 0 {
		return "[]", nil
	}
	b, _ := json.Marshal(data)
	return string(b), nil
}

// readTestLocal reads the local field from test_deps.cue (default "false").
func readTestLocal(ctx *gen.Context, pkgPath string) string {
	relPath := filepath.Join(pkgPath, "test_deps.cue")
	absPath := filepath.Join(ctx.WorkDir, relPath)
	if !fileExists(absPath) {
		return "false"
	}
	val, err := ctx.LoadCUEPackage(relPath, nil)
	if err != nil {
		return "false"
	}
	localVal := val.LookupPath(cue.ParsePath("local"))
	if localVal.Err() != nil {
		return "false"
	}
	b, err := localVal.Bool()
	if err != nil || !b {
		return "false"
	}
	return "true"
}

// ReadDepsJSON reads deps from deps.cue as a JSON array string, or "[]".
func ReadDepsJSON(ctx *gen.Context, pkgPath string) (string, error) {
	relPath := filepath.Join(pkgPath, "deps.cue")
	absPath := filepath.Join(ctx.WorkDir, relPath)
	if !fileExists(absPath) {
		return "[]", nil
	}
	// Load deps.cue as a standalone file (relative to workdir)
	val, err := ctx.LoadCUEPackage(relPath, nil)
	if err != nil {
		return "", fmt.Errorf("load deps.cue in %s: %w", pkgPath, err)
	}
	depsVal := val.LookupPath(cue.ParsePath("deps"))

	deps := []string{}
	iter, err := depsVal.List()
	if err != nil {
		return "", fmt.Errorf("list deps in %s: %w", pkgPath, err)
	}
	for iter.Next() {
		s, _ := iter.Value().String()
		deps = append(deps, s)
	}
	b, _ := json.Marshal(deps)
	return string(b), nil
}

// detectEmbedSrcs scans Go source files for //go:embed directives and returns
// the list of embedded file paths.
func detectEmbedSrcs(dir string, goFiles []string) ([]string, error) {
	seen := map[string]bool{}
	for _, gf := range goFiles {
		f, err := os.Open(filepath.Join(dir, gf))
		if err != nil {
			return nil, err
		}
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if strings.HasPrefix(line, "//go:embed ") {
				pattern := strings.TrimPrefix(line, "//go:embed ")
				// Expand globs relative to the package directory.
				matches, err := filepath.Glob(filepath.Join(dir, pattern))
				if err != nil {
					// Not a glob, treat as literal.
					seen[pattern] = true
					continue
				}
				for _, m := range matches {
					rel, _ := filepath.Rel(dir, m)
					seen[rel] = true
				}
			}
		}
		f.Close()
	}
	if len(seen) == 0 {
		return nil, nil
	}
	var result []string
	for p := range seen {
		result = append(result, p)
	}
	sort.Strings(result)
	return result, nil
}

// autoDeps generates a deps.cue file for a Go package by inspecting imports.
func autoDeps(workDir, pkgPath string, modules []string) error {
	imports, err := goListImports(workDir, pkgPath)
	if err != nil {
		return err
	}

	var labels []string
	for _, imp := range imports {
		label, ok := importToLabel(imp, modules)
		if ok {
			labels = append(labels, label)
		}
	}
	sort.Strings(labels)

	return writeDeps(filepath.Join(workDir, pkgPath, "deps.cue"), labels)
}

// goListImports runs go list -json on a package and returns non-stdlib imports.
func goListImports(workDir, pkgPath string) ([]string, error) {
	var out bytes.Buffer
	if err := runner.Run(context.Background(), runner.Opts{
		Args:   []string{"go", "list", "-json", "./" + pkgPath},
		Dir:    workDir,
		Stdout: &out,
	}); err != nil {
		return nil, fmt.Errorf("go list %s: %w", pkgPath, err)
	}

	var pkg struct {
		Imports []string `json:"Imports"`
	}
	if err := json.Unmarshal(out.Bytes(), &pkg); err != nil {
		return nil, fmt.Errorf("parse go list output: %w", err)
	}

	var result []string
	for _, imp := range pkg.Imports {
		if !isStdlib(imp) {
			result = append(result, imp)
		}
	}
	return result, nil
}

// isStdlib returns true if the import path looks like a stdlib package.
// Stdlib packages never have a dot in the first path segment.
func isStdlib(imp string) bool {
	first := imp
	if i := strings.Index(imp, "/"); i >= 0 {
		first = imp[:i]
	}
	return !strings.Contains(first, ".")
}

// buildModuleMap parses go.mod and returns module paths sorted by length
// descending (for longest-prefix matching).
func buildModuleMap(workDir string) ([]string, error) {
	data, err := os.ReadFile(filepath.Join(workDir, "go.mod"))
	if err != nil {
		return nil, err
	}

	var modules []string
	inRequire := false
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "require (" {
			inRequire = true
			continue
		}
		if line == ")" {
			inRequire = false
			continue
		}
		if inRequire {
			parts := strings.Fields(line)
			if len(parts) >= 2 && !strings.HasPrefix(parts[0], "//") {
				modules = append(modules, parts[0])
			}
		}
	}

	// Sort longest first for prefix matching.
	sort.Slice(modules, func(i, j int) bool {
		return len(modules[i]) > len(modules[j])
	})
	return modules, nil
}

// importToLabel converts a Go import path to a Bazel label.
// Returns ("", false) for imports that should be skipped (stdlib).
func importToLabel(imp string, modules []string) (string, bool) {
	if isStdlib(imp) {
		return "", false
	}

	// Local import: same module.
	if strings.HasPrefix(imp, localModPrefix) {
		rest := strings.TrimPrefix(imp, localModPrefix)
		last := rest[strings.LastIndex(rest, "/")+1:]
		return "//" + rest + ":" + last, true
	}

	// External import: find owning module by longest prefix match.
	var mod string
	for _, m := range modules {
		if imp == m || strings.HasPrefix(imp, m+"/") {
			mod = m
			break
		}
	}
	if mod == "" {
		// Not found in go.mod -- skip (might be vendored or wrong).
		return "", false
	}

	repo := moduleToRepo(mod)
	subpkg := strings.TrimPrefix(imp, mod)
	subpkg = strings.TrimPrefix(subpkg, "/")

	if subpkg == "" {
		// Root package of the module. Apply version suffix logic
		// (e.g., telegram-bot-api/v5 -> target "telegram-bot-api").
		last := bazelTargetName(mod)
		return "@" + repo + "//:" + last, true
	}

	// Subpackage: target name is last segment, but if last segment
	// is a version (v1, v2, etc.), use the segment before it.
	// This matches gazelle's naming for k8s.io/api/core/v1 -> :core.
	last := bazelTargetName(subpkg)
	return "@" + repo + "//" + subpkg + ":" + last, true
}

// moduleToRepo converts a Go module path to a gazelle Bazel repo name.
// Example: "k8s.io/api" -> "io_k8s_api"
// Example: "github.com/go-logr/logr" -> "com_github_go_logr_logr"
// Example: "sigs.k8s.io/controller-runtime" -> "io_k8s_sigs_controller_runtime"
func moduleToRepo(mod string) string {
	parts := strings.Split(mod, "/")

	// Reverse the domain part (first element).
	// "github.com" -> "com_github"
	// "k8s.io" -> "io_k8s"
	// "sigs.k8s.io" -> "io_k8s_sigs"
	domain := parts[0]
	domainParts := strings.Split(domain, ".")
	for i, j := 0, len(domainParts)-1; i < j; i, j = i+1, j-1 {
		domainParts[i], domainParts[j] = domainParts[j], domainParts[i]
	}

	all := append(domainParts, parts[1:]...)

	// Join with underscore, replace hyphens, lowercase.
	// Gazelle lowercases all repo names.
	result := strings.Join(all, "_")
	result = strings.ReplaceAll(result, "-", "_")
	result = strings.ReplaceAll(result, ".", "_")
	return strings.ToLower(result)
}

// bazelTargetName returns the gazelle target name for a subpackage path.
// If the last segment is a Go version suffix (v1, v2, ...), the target
// name is the preceding segment instead (e.g., "core/v1" -> "core").
func bazelTargetName(subpkg string) string {
	parts := strings.Split(subpkg, "/")
	last := parts[len(parts)-1]
	if len(parts) >= 2 && len(last) >= 2 && last[0] == 'v' && last[1] >= '0' && last[1] <= '9' {
		return parts[len(parts)-2]
	}
	return last
}

// writeDeps writes a deps.cue file with the given Bazel labels.
func writeDeps(path string, labels []string) error {
	var buf strings.Builder
	buf.WriteString("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\npackage deps\n\n")
	if len(labels) == 0 {
		buf.WriteString("deps: []\n")
	} else {
		buf.WriteString("deps: [\n")
		for _, l := range labels {
			buf.WriteString("\t\"" + l + "\",\n")
		}
		buf.WriteString("]\n")
	}
	_, err := gen.WriteIfChanged(path, []byte(buf.String()), 0o644)
	return err
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
