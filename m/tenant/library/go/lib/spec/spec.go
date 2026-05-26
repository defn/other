// Package spec provides lattice-based assertion helpers for repository specs.
//
// The lattice is a pre-built JSON snapshot containing the repo's file tree
// (with content), tool versions, and catalog data. Specs validate invariants
// against this snapshot without touching the filesystem.
//
// The lattice lives on disk under kernel/spec/lattice/ as a set of shards
// (one per top-level lattice key, plus one per top-level repo dir under
// tree.dirs) indexed by _index.json. MergeShards reconstructs the merged
// canonical JSON from the shards; LoadLattice unmarshals it for tests.
// See go/lib/gen/lattice for the writer and AIDR-00061 / 00062 for
// downstream consumers (lattice_schema_vet, contracts_vet, spec_test).
package spec

import (
	"bytes"
	"compress/gzip"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"testing"
)

// Lattice is the top-level structure loaded from lattice.json.
type Lattice struct {
	Tree             Dir                    `json:"tree"`
	Versions         map[string]ToolVersion `json:"versions"`
	Bricks           map[string]Brick       `json:"bricks"`
	Apps             map[string]any         `json:"apps"`
	Formatters       map[string]any         `json:"formatters"`
	K3dClusters      map[string]any         `json:"k3d_clusters"`
	K8sPlatforms     map[string]any         `json:"k8s_platforms"`
	Environments     map[string]any         `json:"environments"`
	ChartVersions    map[string]any         `json:"chart_versions"`
	OciImages        map[string]any         `json:"oci_images"`
	ContainerImages  map[string]any         `json:"container_images"`
	ApprovedRequires []string               `json:"approved_requires"`
}

// Dir represents a directory node in the lattice tree.
type Dir struct {
	Type  string          `json:"type"`
	Files map[string]File `json:"files"`
	Dirs  map[string]Dir  `json:"dirs"`
}

// File represents a file or symlink node in the lattice tree.
type File struct {
	Type    string `json:"type"`
	Mode    string `json:"mode"`
	Target  string `json:"target,omitempty"`
	Content string `json:"content,omitempty"`
}

// ToolVersion is a version entry from schema/versions.cue.
type ToolVersion struct {
	Version      string       `json:"version"`
	Sync         []SyncTarget `json:"sync"`
	Constraint   string       `json:"constraint,omitempty"`
	ChartVersion string       `json:"chart_version,omitempty"`
}

// SyncTarget is a file that must contain a version string.
type SyncTarget struct {
	File    string `json:"file"`
	Pattern string `json:"pattern"`
}

// Brick is a catalog entry for a repo component.
type Brick struct {
	Path       string `json:"path"`
	Kind       string `json:"kind"`
	Desc       string `json:"desc"`
	Midas      bool   `json:"midas,omitempty"`
	Implements string `json:"implements,omitempty"`
	Stamping   string `json:"stamping,omitempty"`
	CatalogKey string `json:"catalog_key,omitempty"`
}

// LoadLattice reads the sharded lattice and parses it into a Lattice.
// Looks for kernel/spec/lattice/ relative to the test's working
// directory, or via TEST_SRCDIR for Bazel.
func LoadLattice(t *testing.T) *Lattice {
	t.Helper()

	bazelBase := filepath.Join(os.Getenv("TEST_SRCDIR"), os.Getenv("TEST_WORKSPACE"))
	candidates := []string{
		filepath.Join(bazelBase, "var/lattice"),
		"var/lattice",
		"../../../var/lattice",
	}

	var merged []byte
	var lastErr error
	for _, dir := range candidates {
		if _, err := os.Stat(filepath.Join(dir, "_index.json")); err != nil {
			continue
		}
		merged, lastErr = MergeShards(dir)
		if lastErr == nil {
			break
		}
	}
	if merged == nil {
		if lastErr != nil {
			t.Fatalf("failed to merge lattice shards: %v", lastErr)
		}
		t.Fatalf("failed to find kernel/spec/lattice/_index.json")
	}

	var l Lattice
	if err := json.Unmarshal(merged, &l); err != nil {
		t.Fatalf("failed to parse merged lattice: %v", err)
	}
	return &l
}

// readShardFile reads a shard, decompressing if its name ends in .gz.
func readShardFile(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	if strings.HasSuffix(path, ".gz") {
		gr, err := gzip.NewReader(f)
		if err != nil {
			return nil, err
		}
		defer gr.Close()
		return io.ReadAll(gr)
	}
	return io.ReadAll(f)
}

// shardEntry mirrors one entry in _index.json's shards array.
// Path is a list of JSON-object keys (not a dotted string) so that
// keys containing dots -- e.g. ".aws", ".bazelrc" -- round-trip
// cleanly.
type shardEntry struct {
	Path   []string `json:"path"`
	File   string   `json:"file"`
	Sha256 string   `json:"sha256"`
}

// shardIndex mirrors _index.json.
type shardIndex struct {
	Version       int          `json:"version"`
	LatticeSha256 string       `json:"lattice_sha256"`
	Shards        []shardEntry `json:"shards"`
}

// MergeShards reads kernel/spec/lattice/_index.json under shardDir,
// loads every shard in parallel, verifies each shard's sha256 against
// the manifest, grafts them into a single map at the manifest-recorded
// JSON path, and returns the canonical merged JSON. The returned bytes
// are byte-identical to what the writer would have produced as the
// monolith (sorted keys via Go's json.Marshal, terminating newline);
// the merger verifies this by comparing sha256 against
// manifest.lattice_sha256.
func MergeShards(shardDir string) ([]byte, error) {
	indexBytes, err := os.ReadFile(filepath.Join(shardDir, "_index.json"))
	if err != nil {
		return nil, fmt.Errorf("read _index.json: %w", err)
	}
	var idx shardIndex
	if err := json.Unmarshal(indexBytes, &idx); err != nil {
		return nil, fmt.Errorf("parse _index.json: %w", err)
	}
	if idx.Version != 1 {
		return nil, fmt.Errorf("unsupported _index.json version %d", idx.Version)
	}

	parsed := make([]any, len(idx.Shards))
	errs := make([]error, len(idx.Shards))
	var wg sync.WaitGroup
	for i, sh := range idx.Shards {
		wg.Add(1)
		go func(i int, sh shardEntry) {
			defer wg.Done()
			full := filepath.Join(shardDir, sh.File)
			rawOnDisk, err := os.ReadFile(full)
			if err != nil {
				errs[i] = fmt.Errorf("read shard %s: %w", sh.File, err)
				return
			}
			gotSha := fmt.Sprintf("%x", sha256.Sum256(rawOnDisk))
			if gotSha != sh.Sha256 {
				errs[i] = fmt.Errorf("shard %s sha256 mismatch: have %s, want %s",
					sh.File, gotSha, sh.Sha256)
				return
			}
			var jsonBytes []byte
			if strings.HasSuffix(sh.File, ".gz") {
				gr, err := gzip.NewReader(bytes.NewReader(rawOnDisk))
				if err != nil {
					errs[i] = fmt.Errorf("gunzip shard %s: %w", sh.File, err)
					return
				}
				jsonBytes, err = io.ReadAll(gr)
				gr.Close()
				if err != nil {
					errs[i] = fmt.Errorf("read gzip shard %s: %w", sh.File, err)
					return
				}
			} else {
				jsonBytes = rawOnDisk
			}
			var v any
			if err := json.Unmarshal(jsonBytes, &v); err != nil {
				errs[i] = fmt.Errorf("parse shard %s: %w", sh.File, err)
				return
			}
			parsed[i] = v
		}(i, sh)
	}
	wg.Wait()
	for _, e := range errs {
		if e != nil {
			return nil, e
		}
	}

	root := map[string]any{}
	for i, sh := range idx.Shards {
		graftAtPath(root, sh.Path, parsed[i])
	}

	out, err := json.Marshal(root)
	if err != nil {
		return nil, fmt.Errorf("marshal merged lattice: %w", err)
	}
	out = append(out, '\n')

	gotSha := fmt.Sprintf("%x", sha256.Sum256(out))
	if gotSha != idx.LatticeSha256 {
		return nil, fmt.Errorf("merged lattice sha256 mismatch: have %s, want %s",
			gotSha, idx.LatticeSha256)
	}
	return out, nil
}

// graftAtPath assigns value at the path under root, creating
// intermediate map[string]any nodes as needed. Sufficient because the
// shard layout guarantees disjoint paths (no two shards target the
// same key), so order of grafts does not matter.
func graftAtPath(root map[string]any, parts []string, value any) {
	if len(parts) == 0 {
		return
	}
	cur := root
	for _, p := range parts[:len(parts)-1] {
		next, ok := cur[p].(map[string]any)
		if !ok {
			next = map[string]any{}
			cur[p] = next
		}
		cur = next
	}
	last := parts[len(parts)-1]
	if existing, ok := cur[last].(map[string]any); ok {
		// A previous graft created the parent slot before the shallower
		// shard arrived. Merge: keep keys created downstream, overlay
		// the shallower shard's keys on top. Disjoint by construction
		// in our layout, but defensive.
		if shallow, ok := value.(map[string]any); ok {
			for k, v := range shallow {
				existing[k] = v
			}
			return
		}
	}
	cur[last] = value
}

// pathToKeys converts a file path to lattice tree navigation keys.
// "m/foo/bar.clj" -> navigate dirs["m"] -> dirs["foo"] -> files["bar.clj"]
func (l *Lattice) pathToRel(path string) string {
	path = strings.TrimPrefix(path, "/home/ubuntu/")
	return path
}

// LookupDir navigates the lattice tree to find a directory.
func (l *Lattice) LookupDir(dirPath string) *Dir {
	dirPath = l.pathToRel(dirPath)
	if dirPath == "" {
		return &l.Tree
	}

	current := &l.Tree
	for _, part := range strings.Split(dirPath, "/") {
		sub, ok := current.Dirs[part]
		if !ok {
			return nil
		}
		current = &sub
	}
	return current
}

// LookupFile navigates the lattice tree to find a file entry.
func (l *Lattice) LookupFile(path string) *File {
	path = l.pathToRel(path)
	parts := strings.Split(path, "/")
	if len(parts) == 1 {
		f, ok := l.Tree.Files[parts[0]]
		if !ok {
			return nil
		}
		return &f
	}

	dir := l.LookupDir(strings.Join(parts[:len(parts)-1], "/"))
	if dir == nil {
		return nil
	}
	f, ok := dir.Files[parts[len(parts)-1]]
	if !ok {
		return nil
	}
	return &f
}

// ReadFileContent returns the content of a file from the lattice.
func (l *Lattice) ReadFileContent(path string) (string, bool) {
	f := l.LookupFile(path)
	if f == nil {
		return "", false
	}
	return f.Content, true
}

// FileExists asserts a file exists in the lattice.
func (l *Lattice) FileExists(t *testing.T, path string) {
	t.Helper()
	if l.LookupFile(path) == nil {
		t.Errorf("%s not in lattice", path)
	}
}

// FileNotExists asserts a file does not exist in the lattice.
func (l *Lattice) FileNotExists(t *testing.T, path string) {
	t.Helper()
	if l.LookupFile(path) != nil {
		t.Errorf("%s unexpectedly in lattice", path)
	}
}

// CUEModule returns the workspace's CUE module name from
// cue.mod/module.cue. Used by spec checks that must remain valid
// across forks (AIDR-00138 D5.3 -- kernel substrate has no
// hardcoded module name). Returns the empty string on parse failure.
func (l *Lattice) CUEModule() string {
	c, ok := l.ReadFileContent("m/cue.mod/module.cue")
	if !ok {
		return ""
	}
	// CUE syntax: `module: "github.com/.../..."` on one line.
	for _, line := range strings.Split(c, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module:") {
			rest := strings.TrimSpace(strings.TrimPrefix(line, "module:"))
			rest = strings.Trim(rest, "\"")
			return rest
		}
	}
	return ""
}

// GoModule returns the workspace's Go module name from go.mod.
func (l *Lattice) GoModule() string {
	c, ok := l.ReadFileContent("m/go.mod")
	if !ok {
		return ""
	}
	for _, line := range strings.Split(c, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "module "))
		}
	}
	return ""
}

// FileContains asserts file content contains the literal string.
func (l *Lattice) FileContains(t *testing.T, path, pattern string) {
	t.Helper()
	c, ok := l.ReadFileContent(path)
	if !ok {
		t.Errorf("%s: not found in lattice", path)
		return
	}
	if !strings.Contains(c, pattern) {
		t.Errorf("%s does not contain: %s", path, pattern)
	}
}

// FileNotContains asserts file content does not contain the literal string.
func (l *Lattice) FileNotContains(t *testing.T, path, pattern string) {
	t.Helper()
	c, ok := l.ReadFileContent(path)
	if !ok {
		t.Errorf("%s: not found in lattice", path)
		return
	}
	if strings.Contains(c, pattern) {
		t.Errorf("%s unexpectedly contains: %s", path, pattern)
	}
}

// FileMatches asserts file content matches the regex pattern.
func (l *Lattice) FileMatches(t *testing.T, path, pattern string) {
	t.Helper()
	c, ok := l.ReadFileContent(path)
	if !ok {
		t.Errorf("%s: not found in lattice", path)
		return
	}
	re, err := regexp.Compile(pattern)
	if err != nil {
		t.Fatalf("invalid regex %q: %v", pattern, err)
	}
	if !re.MatchString(c) {
		t.Errorf("%s does not match regex: %s", path, pattern)
	}
}

// SymlinkTarget asserts a file is a symlink pointing to the expected target.
func (l *Lattice) SymlinkTarget(t *testing.T, path, expected string) {
	t.Helper()
	f := l.LookupFile(path)
	if f == nil {
		t.Errorf("%s: not found in lattice", path)
		return
	}
	if f.Type != "symlink" {
		t.Errorf("%s is not a symlink (type=%s)", path, f.Type)
		return
	}
	if f.Target != expected {
		t.Errorf("%s -> %s, expected -> %s", path, f.Target, expected)
	}
}

// FirstLineEquals asserts the first line of file content equals expected.
func (l *Lattice) FirstLineEquals(t *testing.T, path, expected string) {
	t.Helper()
	c, ok := l.ReadFileContent(path)
	if !ok {
		t.Errorf("%s: not found in lattice", path)
		return
	}
	first, _, _ := strings.Cut(c, "\n")
	if first != expected {
		t.Errorf("%s first line is %q, expected %q", path, first, expected)
	}
}

// FileExecutable checks if a file has executable mode.
func (l *Lattice) FileExecutable(path string) bool {
	f := l.LookupFile(path)
	return f != nil && f.Mode == "100755"
}

// VersionSynced asserts a tool's version appears in all its sync target files.
func (l *Lattice) VersionSynced(t *testing.T, toolName string) {
	t.Helper()
	tool, ok := l.Versions[toolName]
	if !ok {
		t.Fatalf("tool %q not found in versions", toolName)
	}
	for _, target := range tool.Sync {
		path := "m/" + target.File
		l.FileContains(t, path, target.Pattern)
	}
}

// LatticeGlob lists files matching a pattern under a directory.
// Supports non-recursive globs (*.md) and recursive globs (**/BUILD.bazel).
func (l *Lattice) LatticeGlob(dirPath, pattern string) []string {
	dir := l.LookupDir(dirPath)
	if dir == nil {
		return nil
	}

	recursive := strings.Contains(pattern, "**")
	if recursive {
		// For **/BUILD.bazel, match any path ending with /BUILD.bazel or just BUILD.bazel
		filePat := strings.Replace(pattern, "**/", "", 1)
		re := globToRegex(filePat)
		var results []string
		collectFiles(dir, "", re, &results)
		sort.Strings(results)
		return results
	}

	re := globToRegex(pattern)
	var results []string
	for name := range dir.Files {
		if re.MatchString(name) {
			results = append(results, name)
		}
	}
	sort.Strings(results)
	return results
}

// LatticeLs lists direct children (files and dirs) in a directory.
func (l *Lattice) LatticeLs(dirPath string) []string {
	dir := l.LookupDir(dirPath)
	if dir == nil {
		return nil
	}
	var names []string
	for name := range dir.Files {
		names = append(names, name)
	}
	for name := range dir.Dirs {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// Version returns the version string for a tool, or empty string if not found.
func (l *Lattice) Version(toolName string) string {
	if v, ok := l.Versions[toolName]; ok {
		return v.Version
	}
	return ""
}

// BrickMap returns a typed accessor for iteration convenience.
func (l *Lattice) BrickMap() map[string]Brick {
	return l.Bricks
}

func collectFiles(dir *Dir, prefix string, re *regexp.Regexp, results *[]string) {
	for name := range dir.Files {
		// Match against just the filename for recursive globs
		if re.MatchString(name) {
			*results = append(*results, prefix+name)
		}
	}
	for name, sub := range dir.Dirs {
		collectFiles(&sub, prefix+name+"/", re, results)
	}
}

func globToRegex(pattern string) *regexp.Regexp {
	escaped := regexp.QuoteMeta(pattern)
	// Restore * as [^/]* (glob wildcard)
	escaped = strings.ReplaceAll(escaped, `\*`, `[^/]*`)
	return regexp.MustCompile("^" + escaped + "$")
}

// Check is a generic assertion helper matching the Clojure (check id cond msg) pattern.
func Check(t *testing.T, condition bool, msgFmt string, args ...any) {
	t.Helper()
	if !condition {
		t.Errorf("%s", fmt.Sprintf(msgFmt, args...))
	}
}
