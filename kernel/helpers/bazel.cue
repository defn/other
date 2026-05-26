@experiment(aliasv2,explicitopen,shortcircuit,try)

// bazel.cue -- standalone helpers for rendering Bazel BUILD.bazel rules.
//
// Used by Midas brick templates:
//   import "github.com/defn/other/kernel/helpers"
//   (helpers.FmtTest & {src: "foo.go", tool: "gofmt"}).out
//
// This package must not import anything outside CUE stdlib.
// Uses public fields (not _hidden) because CUE hidden fields are package-scoped
// and cannot be unified across import boundaries.
package helpers

import "strings"

// FmtTest renders a fmt_test() Bazel rule.
FmtTest: {
	src:  string
	tool: string
	out:  "fmt_test(\n    name = \"" + strings.ToLower(strings.Replace(src, ".", "_", -1)) + "_fmt\",\n    src = \"" + src + "\",\n    tool = \"" + tool + "\",\n)"
}

// TaggedFile renders a tagged_file() Bazel rule.
TaggedFile: {
	src: string
	tags: [...string]
	out: "tagged_file(\n    name = \"" + strings.ToLower(strings.Replace(src, ".", "_", -1)) + "_tag\",\n    src = \"" + src + "\",\n    tags = [\n" + strings.Join([for t in tags {"        \"" + t + "\","}], "\n") + "\n    ],\n)"
}

// FmtLoads is the minimal load() statements for fmt_test + tagged_file.
FmtLoads: """
	load("//kernel:fmt.bzl", "fmt_test")
	load("//kernel:tagged.bzl", "tagged_file")
	"""

// GoLoads is the standard load() statements for Go BUILD.bazel files.
GoLoads: """
	load("@io_bazel_rules_go//go:def.bzl", "go_library")
	load("//kernel:fmt.bzl", "fmt_test")
	load("//kernel:tagged.bzl", "tagged_file", "tagged_package")
	"""

// BuildBazelFmt is the fmt_test for BUILD.bazel itself (used in every template).
BuildBazelFmt: (FmtTest & {src: "BUILD.bazel", tool: "buildifier"}).out

// BuildBazelTag is the tagged_file for BUILD.bazel itself (used in every template).
BuildBazelTag: (TaggedFile & {src: "BUILD.bazel", tags: ["bazel", "bazel-build"]}).out

// DispatchCueRules emits glob-conditional fmt_test + tagged_file rules
// for AIDR-00132 OQ7's per-brick `dispatch.cue`. The rules are no-ops
// while the `dispatchworker` generator is dormant (no dispatch.cue on
// disk -> empty glob -> empty list comprehension); once activated they
// claim each emitted file. Per-brick BUILD.bazel templates append this
// block so every brick is BUILD-ready before activation flips.
DispatchCueRules: """
	[fmt_test(
	    name = "dispatch_cue_fmt",
	    src = src,
	    tool = "cue",
	) for src in glob(["dispatch.cue"], allow_empty = True)]

	[tagged_file(
	    name = "dispatch_cue_tag",
	    src = src,
	    tags = [
	        "cue",
	        "source",
	    ],
	) for src in glob(["dispatch.cue"], allow_empty = True)]
	"""
