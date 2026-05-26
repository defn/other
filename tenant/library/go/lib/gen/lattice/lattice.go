// Package lattice generates the sharded spec/lattice tree.
//
// Builds the lattice from the Go gen.Context (which has the CUE catalog
// and schema loaded) and the in-memory file tree, then writes one
// shard per top-level lattice key (plus per top-level repo dir under
// tree.dirs) into var/lattice/. An index file (_index.json)
// lists the shards with their sha256 digests so the merger and the Go
// LoadLattice helper can verify integrity.
//
// Why shards: the monolithic lattice.json.gz used to churn ~3.9 MB on
// every commit that touched any file's content (BUILD.bazel,
// .bazelrc, etc.) because the lattice inlines file contents. Sharding
// by JSON path means a one-line edit to a Go file under m/go only
// rewrites tree--dirs--m.json.gz; the other shards stay byte-identical
// and produce no git diff.
//
// Encoding: shards are written as plain canonical JSON unless their
// raw size exceeds gzipThreshold, in which case they are gzipped. The
// rate of change is low enough per shard that plain JSON gives
// human-readable git diffs for typical edits; only the bulky
// tree--dirs--m payload routinely crosses the threshold.
//
// All bytes are deterministic functions of the input: JSON keys are
// sorted (Go's json.Marshal sorts map[string]any), gzip header ModTime
// is zeroed, gzip header OS byte is forced to 255 (unknown).
package lattice

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync/atomic"
	"time"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// shardDirRel is the workspace-relative directory holding all shards.
const shardDirRel = "var/lattice"

// indexName is the manifest filename inside shardDirRel. Always plain
// JSON -- the manifest itself is tiny and benefits from readable diffs.
const indexName = "_index.json"

// indexNameSha is the lattice-wide content digest filename. Its value
// is the sha256 of the merged canonical lattice JSON (NOT the digest
// of the index file). Used by Run for short-circuit comparison and by
// the merger to verify a successful round-trip.
const indexNameSha = "_index.sha256"

// gzipThreshold is the raw-JSON size above which a shard is gzipped.
// Below the threshold we keep plain JSON for human-readable diffs; the
// few shards that exceed it compress well, so the storage saving is
// worth the diff opacity.
const gzipThreshold = 64 * 1024

// recursionThreshold is the raw-JSON size above which a tree-dir node
// is split into a parent shard (everything except dirs) plus one
// shard per immediate child dir, recursively. Sized so the only
// subtrees that fragment are those whose churn would otherwise force
// a multi-MB shard rewrite for an unrelated edit. Smaller subtrees
// stay in their parent shard to keep file count manageable.
const recursionThreshold = 1 * 1024 * 1024

// monolithJSONGz / monolithSHA are the legacy filenames; Run removes
// them on the first sharded run so they don't linger in git.
const monolithJSONGz = "var/lattice.json.gz"
const monolithSHA = "var/lattice.json.sha256"
const monolithJSON = "var/lattice.json"

// skipEnrich returns true for binary/generated files that should not be inlined.
func skipEnrich(name string) bool {
	for _, s := range []string{".gz", ".tgz", ".jar", ".sha256"} {
		if strings.HasSuffix(name, s) {
			return true
		}
	}
	return false
}

// Run generates the sharded lattice under var/lattice/.
// Returns nil on success; lastStatus carries the human-readable summary.
func Run(ctx *gen.Context) error {
	lattice := buildLattice(ctx)
	if err := enrichLatticeTree(ctx, lattice); err != nil {
		return err
	}

	// Canonical JSON of the full merged lattice. Only used to compute
	// the lattice-wide digest (short-circuit) and to size the status
	// message; never written to disk in sharded mode.
	mergedJSON, err := json.Marshal(lattice)
	if err != nil {
		return fmt.Errorf("marshal merged lattice: %w", err)
	}
	mergedJSON = append(mergedJSON, '\n')
	digest := fmt.Sprintf("%x", sha256.Sum256(mergedJSON))

	shardDir := filepath.Join(ctx.WorkDir, shardDirRel)
	if err := os.MkdirAll(shardDir, 0o755); err != nil {
		return fmt.Errorf("mkdir shard dir: %w", err)
	}

	// Short-circuit: if the prior _index.sha256 matches, no shard's
	// content changed, so neither did the manifest. Skip all writes.
	indexShaPath := filepath.Join(shardDir, indexNameSha)
	if old, rerr := os.ReadFile(indexShaPath); rerr == nil && strings.TrimSpace(string(old)) == digest {
		removeMonolith(ctx) // safe to call even when already removed
		lastStatus.Store(fmt.Sprintf("var/lattice unchanged (%.1f MB merged), skipping",
			float64(len(mergedJSON))/1048576.0))
		ctx.LogOK(lastStatus.Load().(string))
		return nil
	}

	shards := splitIntoShards(lattice)

	// Write each shard. Plain JSON below gzipThreshold, gzip above.
	// The manifest records the actual filename so loaders never have
	// to guess. sha256 is taken over the on-disk bytes (post-gzip),
	// which is what readers can verify.
	//
	// path is a list of components rather than a dotted string because
	// repo dirs have leading dots (".aws", ".config"); a dotted-string
	// encoding round-trips wrong (".aws" -> "tree.dirs..aws" splits to
	// ["tree","dirs","","aws"]).
	type entry struct {
		Path   []string `json:"path"`
		File   string   `json:"file"`
		Sha256 string   `json:"sha256"`
	}
	entries := make([]entry, 0, len(shards))
	written := map[string]bool{}
	for _, sh := range shards {
		raw, err := json.Marshal(sh.value)
		if err != nil {
			return fmt.Errorf("marshal shard %v: %w", sh.path, err)
		}
		raw = append(raw, '\n')

		var bytesOnDisk []byte
		baseFname := shardFilename(sh.path)
		fname := baseFname
		if len(raw) >= gzipThreshold {
			bytesOnDisk, err = encodeGzip(raw)
			if err != nil {
				return fmt.Errorf("gzip shard %v: %w", sh.path, err)
			}
			fname += ".gz"
		} else {
			bytesOnDisk = raw
		}
		if _, err := gen.WriteIfChanged(filepath.Join(shardDir, fname), bytesOnDisk, 0o644); err != nil {
			return fmt.Errorf("write shard %s: %w", fname, err)
		}
		// Threshold crossings (plain <-> gzip) leave a stale sibling
		// from the prior run; strip it eagerly so the shard dir never
		// holds two encodings of the same payload. pruneStaleShards
		// catches this dir-wide later, but doing it per-shard keeps
		// the intent local to where the format choice is made.
		if fname == baseFname {
			_ = os.Remove(filepath.Join(shardDir, baseFname+".gz"))
		} else {
			_ = os.Remove(filepath.Join(shardDir, baseFname))
		}
		entries = append(entries, entry{
			Path:   sh.path,
			File:   fname,
			Sha256: fmt.Sprintf("%x", sha256.Sum256(bytesOnDisk)),
		})
		written[fname] = true
	}
	// Sort by joined path string for stability.
	sort.Slice(entries, func(i, j int) bool {
		return strings.Join(entries[i].Path, "\x00") < strings.Join(entries[j].Path, "\x00")
	})

	// Manifest: opaque to filename layout. Loaders use it as the source
	// of truth for which shards exist and what JSON path each represents.
	manifest := map[string]any{
		"version":        1,
		"lattice_sha256": digest,
		"shards":         entries,
	}
	manifestBytes, err := json.Marshal(manifest)
	if err != nil {
		return fmt.Errorf("marshal manifest: %w", err)
	}
	manifestBytes = append(manifestBytes, '\n')
	if _, err := gen.WriteIfChanged(filepath.Join(shardDir, indexName), manifestBytes, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", indexName, err)
	}
	written[indexName] = true
	if _, err := gen.WriteIfChanged(indexShaPath, []byte(digest+"\n"), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", indexNameSha, err)
	}
	written[indexNameSha] = true

	// Garbage-collect stale shards from prior runs whose JSON path no
	// longer exists. Without this, a removed top-level dir under
	// tree.dirs would leave its tree--dirs--<name>.json.gz orphaned.
	if err := pruneStaleShards(shardDir, written); err != nil {
		return fmt.Errorf("prune shards: %w", err)
	}

	removeMonolith(ctx)

	lastStatus.Store(fmt.Sprintf("generated var/lattice/ (%d shards, %.1f MB merged)",
		len(entries), float64(len(mergedJSON))/1048576.0))
	ctx.LogOK(lastStatus.Load().(string))
	return nil
}

// lastStatus holds the message recorded by the most recent Run call so
// Status can return it without re-deriving from mtimes.
var lastStatus atomic.Value

// Status returns the message recorded by the most recent Run call.
func Status(_ string) string {
	v := lastStatus.Load()
	if v == nil {
		return ""
	}
	return v.(string)
}

// buildLattice assembles the in-memory lattice map by extracting
// fields from the already-loaded CUE values on ctx. No CUE re-eval.
func buildLattice(ctx *gen.Context) map[string]any {
	lattice := map[string]any{}

	catalogFields := []string{
		"formatters", "apps", "k3d_clusters", "k8s_platforms",
		"environments", "chart_versions", "oci_images",
		"container_images", "bricks", "skills",
		"aws_tofu_apps", "aws_orgs", "aws_accounts", "auth",
	}
	for _, field := range catalogFields {
		v := ctx.CatalogQuery(field)
		jsonBytes, err := v.MarshalJSON()
		if err != nil {
			// Field absent from catalog: emit an empty map so CUE
			// contracts that bind it via `<field>: _` and iterate
			// see an empty iteration, not a bottom value. Without
			// this, a fork with no aws_tofu_apps (etc.) sees the
			// contract's comprehension produce _|_ which propagates
			// into orphan/missingClaim explosions.
			lattice[field] = map[string]any{}
			continue
		}
		var m any
		_ = json.Unmarshal(jsonBytes, &m)
		lattice[field] = m
	}

	// default_tenant is a scalar catalog field; contracts read it to
	// know which tenant tree they're stamping into (AIDR-00138 D5.3).
	lattice["default_tenant"] = ctx.DefaultTenant()

	if arJSON, err := ctx.CatalogQuery("scripting_policy.approved_requires").MarshalJSON(); err == nil {
		var ar any
		_ = json.Unmarshal(arJSON, &ar)
		lattice["approved_requires"] = ar
	}

	if vJSON, err := ctx.SchemaQuery("versions").MarshalJSON(); err == nil {
		var versions any
		_ = json.Unmarshal(vJSON, &versions)
		lattice["versions"] = versions
	}

	var tree map[string]any
	if ctx.SpecTree != nil {
		tree = ctx.SpecTree.(map[string]any)
	} else {
		// Fallback: load from CUE (for standalone lattice runs).
		specVal, err := ctx.LoadCUEPackage("./kernel/spec", nil)
		if err == nil {
			treeVal := specVal.LookupPath(cue.ParsePath("lattice.tree"))
			if treeJSON, err := treeVal.MarshalJSON(); err == nil {
				_ = json.Unmarshal(treeJSON, &tree)
			}
		}
	}
	lattice["tree"] = tree
	return lattice
}

// enrichLatticeTree walks lattice["tree"] and inlines the working-tree
// content of every regular file (skipping binaries via skipEnrich).
func enrichLatticeTree(ctx *gen.Context, lattice map[string]any) error {
	repoRoot, err := runner.Output(context.Background(), runner.Opts{
		Args: []string{"git", "rev-parse", "--show-toplevel"},
		Dir:  ctx.WorkDir,
	})
	if err != nil {
		return fmt.Errorf("git rev-parse: %w", err)
	}
	tree, _ := lattice["tree"].(map[string]any)
	if tree != nil {
		enrichTree(tree, repoRoot, "")
	}
	return nil
}

// shard is a single (JSON-path, value) pair to be written as one file.
// path is a list of JSON-object keys; using a list (not a dotted
// string) avoids ambiguity when keys themselves contain dots
// (".aws", ".bazelrc", etc.).
type shard struct {
	path  []string
	value any
}

// splitIntoShards walks lattice and produces a list of (path, value)
// shards. Top-level non-tree keys each become one shard. The tree is
// recursively split: any tree-dir node whose marshaled JSON exceeds
// recursionThreshold is broken into a parent shard ({type, files,
// ...everything except dirs}) plus one shard per immediate child of
// dirs, then each child is itself recursively split if still too
// large. The original lattice map is not mutated -- parent shards
// hold a fresh map[string]any without the dirs key, while leaves
// alias the source subtree.
func splitIntoShards(lattice map[string]any) []shard {
	out := make([]shard, 0, 64)
	for k, v := range lattice {
		if k == "tree" {
			continue
		}
		out = append(out, shard{path: []string{k}, value: v})
	}
	if tree, ok := lattice["tree"].(map[string]any); ok && tree != nil {
		splitTreeNode([]string{"tree"}, tree, &out)
	}
	sortShards(out)
	return out
}

// splitTreeNode recursively shards a tree-dir node. If the node's raw
// JSON is small enough OR it has no dirs to split, it is emitted
// whole. Otherwise the parent emits without its dirs and each
// immediate child becomes its own (recursively split) shard.
func splitTreeNode(path []string, node map[string]any, out *[]shard) {
	raw, err := json.Marshal(node)
	if err != nil || len(raw) < recursionThreshold {
		*out = append(*out, shard{path: append([]string(nil), path...), value: node})
		return
	}
	dirs, hasDirs := node["dirs"].(map[string]any)
	if !hasDirs || len(dirs) == 0 {
		*out = append(*out, shard{path: append([]string(nil), path...), value: node})
		return
	}
	parent := map[string]any{}
	for k, v := range node {
		if k == "dirs" {
			continue
		}
		parent[k] = v
	}
	*out = append(*out, shard{path: append([]string(nil), path...), value: parent})
	for childName, childAny := range dirs {
		childPath := append(append([]string(nil), path...), "dirs", childName)
		childMap, ok := childAny.(map[string]any)
		if !ok {
			*out = append(*out, shard{path: childPath, value: childAny})
			continue
		}
		splitTreeNode(childPath, childMap, out)
	}
}

func sortShards(s []shard) {
	sort.Slice(s, func(i, j int) bool {
		return strings.Join(s[i].path, "\x00") < strings.Join(s[j].path, "\x00")
	})
}

// shardFilename converts a path-component list into a deterministic
// base filename inside the shard dir (always ending in .json). Each
// component is joined with '--' rather than '.'  so leading-dot
// components (".aws", ".bazelrc") and the separator stay distinct in
// the filename. Callers append ".gz" when gzipping. Filenames are
// opaque to the loader -- the manifest carries the canonical
// path -- but we keep them human-readable. Components are assumed to
// contain no '/' (true of every JSON key in the lattice).
func shardFilename(path []string) string {
	return strings.Join(path, "--") + ".json"
}

// pruneStaleShards removes any shard file in shardDir not present in
// keep. Leaves BUILD.bazel and any other non-shard file alone.
// Required because dropping a top-level repo dir under tree.dirs (or
// crossing the gzip threshold in either direction) would otherwise
// orphan the previous shard file.
func pruneStaleShards(shardDir string, keep map[string]bool) error {
	entries, err := os.ReadDir(shardDir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		isShard := strings.HasSuffix(name, ".json") ||
			strings.HasSuffix(name, ".json.gz") ||
			strings.HasSuffix(name, ".sha256")
		if !isShard {
			continue
		}
		if keep[name] {
			continue
		}
		if err := os.Remove(filepath.Join(shardDir, name)); err != nil {
			return err
		}
	}
	return nil
}

// removeMonolith deletes the legacy single-file lattice artifacts. Run
// invokes this after a successful sharded write so a clone with the
// old files transitions cleanly. Errors are intentionally ignored:
// this is a one-shot migration helper, not a correctness invariant.
func removeMonolith(ctx *gen.Context) {
	for _, rel := range []string{monolithJSONGz, monolithSHA, monolithJSON} {
		_ = os.Remove(filepath.Join(ctx.WorkDir, rel))
	}
}

// shardSubtreeRel is the workspace-relative path to the shard
// directory itself, used to break a feedback loop: every shard's
// content includes a sha256 of every other shard, so if we inlined
// _index.json (a tracked file under m/) into tree--dirs--m.json.gz,
// editing any shard would force tree--dirs--m to update again on the
// next gen run, causing perpetual non-idempotency.
const shardSubtreeRel = "m/" + shardDirRel

func enrichTree(tree map[string]any, basePath, treeRel string) {
	if treeRel == shardSubtreeRel {
		return
	}
	if files, ok := tree["files"].(map[string]any); ok {
		for fname, entry := range files {
			m, ok := entry.(map[string]any)
			if !ok {
				continue
			}
			if m["type"] != "file" || skipEnrich(fname) {
				continue
			}
			data, err := os.ReadFile(filepath.Join(basePath, fname))
			if err != nil {
				continue
			}
			m["content"] = strings.TrimSpace(string(data))
		}
	}
	if dirs, ok := tree["dirs"].(map[string]any); ok {
		for dname, subtree := range dirs {
			if m, ok := subtree.(map[string]any); ok {
				subRel := dname
				if treeRel != "" {
					subRel = treeRel + "/" + dname
				}
				enrichTree(m, filepath.Join(basePath, dname), subRel)
			}
		}
	}
}

func encodeGzip(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	w, err := gzip.NewWriterLevel(&buf, gzip.DefaultCompression)
	if err != nil {
		return nil, err
	}
	w.Header.ModTime = time.Time{}
	w.Header.OS = 255
	if _, err := w.Write(data); err != nil {
		w.Close()
		return nil, err
	}
	if err := w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}
