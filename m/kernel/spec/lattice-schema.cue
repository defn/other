@experiment(aliasv2,explicitopen,shortcircuit,try)

// Lattice schema: CUE constraints that validate spec/lattice.json.
// Run with: cue vet spec/lattice.json spec/lattice-schema.cue
//
// This file is the CUE-native home for repo invariants that used to
// live as Go subtests in go/lib/spec/spec_test.go. Each spec that
// moves here deletes a Go subtest. See AIDR-00061 for rationale.
//
// ---- Gotchas captured during migration (do not rediscover) ---------
//
// 1. Field-pattern intersection.  CUE supports combining regex
//    constraints on field names via `&`, e.g.
//        [=~ #"\.cue$"# & !~ #"^gen-"#]: T
//    applies T to any field whose key matches BOTH the positive and
//    negative regex. This replaces the Go pattern "find all X, then
//    filter out Y" with a single pattern constraint. No lookahead
//    needed -- CUE RE2 cannot express lookaround, so compose with `&`.
//
// 2. Regex anchoring matches the indented form.  The lattice preserves
//    file content byte-for-byte, including leading tabs. A regex like
//    `^[a-z_]*build_bazel:` misses `build_bazel:` lines that are
//    indented inside `if` blocks. Use `(?m)^\t*[a-z_]*build_bazel:`
//    to match the indented form; mirror whatever the original Go test
//    used.
//
// 3. Forbidden-keys pattern.  To require that every file under a dir
//    matches an allowed filename pattern, use a two-pattern-constraint
//    form:
//        files: {
//            [=~ allowed]: _
//            [!~ allowed]: _|_
//        }
//    The first allows, the second forbids. This depends on the struct
//    staying open (`...`), otherwise closed-struct rules can mask the
//    forbidden branch.
//
// 4. `cue.mod/pkg/` vendored CUE packages are NOT tracked in the
//    lattice, so the Go-test-era "skip cue.mod/pkg" branch has no
//    corresponding CUE work.
//
// 5. Conditional-on-content specs (e.g. "only check if content
//    contains X") do not map cleanly to CUE pattern constraints.
//    They can be expressed as a disjunction `content: =~ required |
//    !~ trigger` but read awkwardly. Leave those in Go for now.
//
// 6. Version sync is beautifully expressible.  The lattice strips
//    trailing newlines from file content, so
//        files: ".bazelversion": content: versions.bazel.version
//    is a direct string equality between the canonical version in
//    schema/versions.cue and the bytes on disk. Same shape works for
//    any text-pinned version file.
//
// 7. Cost profile.  `cue vet` against the 35 MB lattice.json is
//    ~1.04s flat (CUE startup + JSON parse). Every constraint added
//    to this file costs O(ms) on top. Twelve specs cost ~50ms over
//    baseline, so pack freely.
//
// --------------------------------------------------------------------

package latticeschema

// ---- reusable helpers --------------------------------------------------

#CueFile: {
	type:    "file"
	content: =~#"@experiment\(aliasv2,explicitopen,shortcircuit,try\)"#
	...
}

#TemplatesCue: {
	type:    "file"
	content: =~#"(?m)^\t*[a-z_]*build_bazel:"#
	content: =~#"@tag\("#
	...
}

// Recursive walker for SPEC-00277 and templates.cue constraints.
// Note `files` is kept open via `...`; closed-struct semantics would
// make the pattern-constraint branches unreachable.
#Dir: {
	type: "dir"
	files?: {
		[string]:       _
		[=~#"\.cue$"#]: #CueFile
	}
	dirs?: [string]: #Dir
	...
}

#InterfaceDir: {
	#Dir
	files?: {
		[string]:         _
		"templates.cue"?: #TemplatesCue
		[=~#"\.cue$"#]:   #CueFile
	}
	dirs?: [string]: #InterfaceDir
	...
}

// ---- lattice top-level surface referenced below ------------------------

versions: bazel: version: string

// ========================================================================
// SPEC-00004: CLAUDE.md at repo root is a symlink to m/root/AGENTS.md
// ========================================================================
tree: files: "CLAUDE.md": {
	type:   "symlink"
	target: "m/root/AGENTS.md"
	...
}

// ========================================================================
// SPEC-00006: .bazelversion at repo root is a symlink to m/.bazelversion
// ========================================================================
tree: files: ".bazelversion": {
	type:   "symlink"
	target: "m/.bazelversion"
	...
}

// ========================================================================
// SPEC-00012: .bazelversion content matches schema/versions.cue
// ========================================================================
tree: dirs: m: files: ".bazelversion": {
	type:    "file"
	content: versions.bazel.version
	...
}

// ========================================================================
// SPEC-00277: All non-generated .cue files under m/ carry the @experiment
// header. Walks recursively via #Dir.
// ========================================================================
tree: dirs: m: #Dir

// ========================================================================
// SPEC-00280 + SPEC-00281: Every interface templates.cue has a build_bazel
// field (tab-indented or flush left) and uses @tag(...).
// ========================================================================
tree: dirs: m: dirs: kernel: dirs: interface: #InterfaceDir

// ========================================================================
// SPEC-00007: AIDRs match NNNNN-topic-name.md (plus AGENTS.md, BUILD.bazel)
// ========================================================================
tree: dirs: m: dirs: aidr: files: {
	[=~#"^(?:[0-9]{5}-[a-z0-9-]+\.md|AGENTS\.md|BUILD\.bazel|dispatch\.cue)$"#]: _
	[!~#"^(?:[0-9]{5}-[a-z0-9-]+\.md|AGENTS\.md|BUILD\.bazel|dispatch\.cue)$"#]: _|_
}

// ========================================================================
// SPEC-00283: OCI bricks have structurally correct BUILD.bazel
// ========================================================================
tree: dirs: m: dirs: oci: dirs: [string]: {
	type: "dir"
	files?: "BUILD.bazel"?: {
		type:    "file"
		content: =~#"load\(\"//kernel:fmt\.bzl\""#
		content: =~#"load\(\"//kernel:tagged\.bzl\""#
		content: =~"build_bazel_fmt"
		content: =~"build_bazel_tag"
		...
	}
	...
}

// ========================================================================
// SPEC-00284: image/docker bricks have BUILD.bazel with required entries
// ========================================================================
tree: dirs: m: dirs: image: dirs: docker: dirs: [string]: {
	type: "dir"
	files?: "BUILD.bazel"?: {
		type:    "file"
		content: =~"dockerfile_fmt"
		content: =~"dockerfile_tag"
		content: =~"mise_toml_fmt"
		content: =~"mise_toml_tag"
		content: =~#"\"Dockerfile\""#
		content: =~#"\"mise\.toml\""#
		...
	}
	...
}

// ========================================================================
// SPEC-00285: image/docker bricks mise.toml has IMAGE_TAG and BASE_IMAGE
// ========================================================================
tree: dirs: m: dirs: image: dirs: docker: dirs: [string]: {
	type: "dir"
	files?: "mise.toml"?: {
		type:    "file"
		content: =~"IMAGE_TAG"
		content: =~"BASE_IMAGE"
		...
	}
	...
}

// ========================================================================
// SPEC-00286: k8s bricks have platform_cue_fmt and platform_cue_tag
// ========================================================================
tree: dirs: m: dirs: k8s: dirs: [string]: {
	type: "dir"
	files?: "BUILD.bazel"?: {
		type:    "file"
		content: =~"platform_cue_fmt"
		content: =~"platform_cue_tag"
		...
	}
	...
}

// ========================================================================
// SPEC-00289: interface/app/templates.cue covers all three app kinds
// ========================================================================
tree: dirs: m: dirs: kernel: dirs: interface: dirs: app: files: "templates.cue": {
	type: "file"
	// AIDR-00147: kustomize is covered by the source + var-render templates
	// (the single-package kustomize_build_bazel was retired post-AIDR-00146).
	content: =~"kustomize_source_build_bazel:"
	content: =~"kustomize_render_build_bazel:"
	content: =~"versioned_build_bazel:"
	content: =~"raw_build_bazel:"
	...
}
