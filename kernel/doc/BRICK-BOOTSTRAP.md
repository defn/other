# Bootstrapping the BRICK System

How to graft the minimum viable brick classification system into a repository's
`m/` directory. This document is the step-by-step complement to `BRICK.md`
(theory) and `BRICK-GO.md` (Go-specific patterns).

---

## Prerequisites

Before grafting, the target repo needs:

- **Bazel** with bzlmod (`MODULE.bazel`, at least one `BUILD.bazel`)
- **CUE module** (`cue.mod/` at the repo root or under `m/`)
- **Directories with BUILD.bazel files** -- these become the blocks to classify

If the repo already has CUE and Bazel, the brick system slots in alongside
them. If not, set those up first.

---

## Skeleton File Tree

Create these files under `m/`:

```
m/
├── BUILD.bazel              # exports tagged.bzl
├── tagged.bzl               # tagged_file() Bazel macro
├── schema/
│   ├── brick.cue            # #Brick, #BrickKind, #StampingMethod
│   └── BUILD.bazel          # cue_eval_test
├── catalog/
│   ├── bricks.cue           # directory classifications
│   ├── catalog.cue          # derived queries
│   └── BUILD.bazel          # cue_eval_test
├── helpers/
│   ├── bazel.cue            # TaggedFile, FmtTest renderers
│   └── BUILD.bazel          # cue_eval_test
└── interface/               # Midas interfaces (add as needed)
    └── (empty initially)
```

Each file is described below with its complete contents.

---

## 1. Schema: `m/schema/brick.cue`

The type system. Copy this verbatim, then update the `package` line if your
CUE module uses a different package name.

```cue
@experiment(aliasv2,explicitopen,try)

// Package schema defines the BRICK directory classification system.
//
// BRICK: Building block, Role, Implementation, Configuration, Kit.
// Five registers on every platform artifact. See doc/BRICK.md.
//
// Every directory with a BUILD.bazel is a Block, classified as one of:
//   - relationship: defines how directories connect/validate
//   - interface:    defines contracts, types, schemas, templates
//   - component:    concrete instance producing artifacts
//   - branch:       composes other blocks into a cohesive unit
//                   (formerly named "kit" -- per AIDR-00083:
//                   branches compute from leaves)
package schema

#BrickKind: "relationship" | "interface" | "component" | "branch"

// #StampingMethod describes how a Midas interface stamps out components.
//   - macro:     interface/{name}/{name}.bzl exists, components call it
//   - generator: a code generator stamps components from CUE templates
#StampingMethod: "macro" | "generator"

#Brick: {
	path:  string
	kind:  #BrickKind
	desc?: string
	composes?: [...string]
	implements?: string

	// Midas fields -- required when midas is true.
	midas?:       bool
	stamping?:    #StampingMethod
	catalog_key?: string

	// Only branch bricks may have composes.
	if kind != "branch" {
		composes?: []
	}

	// Only component bricks may have implements.
	if kind != "component" {
		implements?: ""
	}

	// Only interface bricks may be midas.
	if kind != "interface" {
		midas?: false
	}

	// Midas interfaces must declare stamping and catalog_key.
	// Non-midas bricks must not have them.
	try {
		if midas? == true {
			stamping:    #StampingMethod
			catalog_key: string
		}
		if midas? != true {
			stamping?:    _|_
			catalog_key?: _|_
		}
	} else {
		stamping?:    _|_
		catalog_key?: _|_
	}
}
```

### `m/schema/BUILD.bazel`

```starlark
load("//path/to/cue:cue.bzl", "cue_eval_test")

cue_eval_test(
    name = "cue_eval",
)
```

Adjust the load path to match your repo's CUE Bazel macro location.

---

## 2. Catalog: `m/catalog/bricks.cue`

The inventory. Start with a root branch and classify your major directories.
You do not need to cover every directory -- start with 15-30 and expand
incrementally.

```cue
@experiment(aliasv2,explicitopen,try)

// bricks.cue -- BRICK directory classification inventory.
//
// Every directory with a BUILD.bazel is registered here with its
// path, kind, and optional description. See schema.#Brick for
// the type definition.
package catalog

import "<your-cue-module>/m/schema"

bricks: [string]: schema.#Brick

bricks: {
	// Root -- branch composing all top-level blocks
	"": {
		path: ""
		kind: "branch"
		desc: "monorepo root composing all top-level blocks"
		composes: [
			// List your top-level directories here
		]
	}

	// Add entries for each classified directory.
	// See "Choosing Brick Kind" below for guidance.
}
```

### Choosing Brick Kind

Use this decision tree:

| Question                                                                                      | If yes           | If no      |
| --------------------------------------------------------------------------------------------- | ---------------- | ---------- |
| Does this directory define how other directories connect or validate?                         | **relationship** | next       |
| Does this directory define contracts, schemas, or templates that other directories implement? | **interface**    | next       |
| Does this directory compose other classified directories into a cohesive unit?                | **kit**          | next       |
| Does this directory produce a concrete artifact (binary, image, manifest, config)?            | **component**    | reconsider |

Common mappings:

| Directory type           | Brick kind   | Example                  |
| ------------------------ | ------------ | ------------------------ |
| Go CLI command           | component    | `cmd/serve`              |
| Go library package       | component    | `lib/auth`               |
| Python package           | component    | `agents/`                |
| Infrastructure workspace | component    | `infra/prod/`            |
| Helm chart / K8s app     | component    | `app/redis/`             |
| Schema definitions       | interface    | `schema/`                |
| Build macros / rules     | relationship | `build-rules/`           |
| Validation / linting     | relationship | `lint/`                  |
| Top-level grouping dir   | kit          | `cmd/`, `lib/`, `infra/` |

### Midas interfaces

When a directory is an interface that stamps out components (generates
BUILD.bazel, boilerplate code, or config from CUE templates), mark it as
Midas:

```cue
"interface/go-cmd": {
	path:        "interface/go-cmd"
	kind:        "interface"
	desc:        "Go cobra command contract and templates"
	midas:       true
	stamping:    "generator"
	catalog_key: "go_cmd_bricks"
}
```

Components that implement a Midas interface use the `implements` field:

```cue
"cmd/serve": {
	path:       "cmd/serve"
	kind:       "component"
	desc:       "HTTP API server"
	implements: "interface/go-cmd"
}
```

Do not create Midas interfaces until you have at least two components that
share enough structure to justify stamping. Start with plain classification.

---

## 3. Derived Queries: `m/catalog/catalog.cue`

Computed views over the brick catalog. These power generators and queries.

```cue
@experiment(aliasv2,explicitopen,try)

// catalog.cue -- derived queries over the brick catalog.
package catalog

import "strings"

// _components: all component bricks with a concrete implements field.
_components: {for _, b in bricks
	if b.kind == "component"
	if (b & {implements: string}).implements != _|_ {
		(b.path): b
	}}

// Bricks by kind.
branch_bricks:       {for p, b in bricks if b.kind == "branch" {(p): b}}
interface_bricks:    {for p, b in bricks if b.kind == "interface" {(p): b}}
component_bricks:    {for p, b in bricks if b.kind == "component" {(p): b}}
relationship_bricks: {for p, b in bricks if b.kind == "relationship" {(p): b}}

// Add per-interface queries as Midas interfaces are introduced:
//
// go_cmd_bricks: {for p, b in _components
//     if b.implements == "interface/go-cmd" {(p): b}}
//
// go_lib_bricks: {for p, b in _components
//     if b.implements == "interface/go-lib" {(p): b}}
```

### `m/catalog/BUILD.bazel`

```starlark
load("//path/to/cue:cue.bzl", "cue_eval_test")

cue_eval_test(
    name = "cue_eval",
)
```

---

## 4. Tagged File Macro: `m/tagged.bzl`

Tags files with metadata queryable via `bazelisk query`. Start with the
simplified version (no executable permission test).

```starlark
# tagged.bzl -- Starlark macro for tagging files with metadata.
#
# Usage in BUILD.bazel:
#   load("//m:tagged.bzl", "tagged_file")
#   tagged_file(name = "my_config_tag", src = "config.yaml", tags = ["config", "yaml"])
#
# Tags are queryable via:
#   bazelisk query 'attr(tags, "\\bmise-task\\b", //...)'
#
# Implicit behavior:
#   - Tags "script" and "mise-task" imply "executable"
#
# Tag taxonomy:
#   Category tags (what the file is):
#     bazel-build   BUILD.bazel files
#     bazel-config  .bazelrc, .bazelversion
#     bazel-macro   .bzl macro/rule files
#     bazel-module  MODULE.bazel, WORKSPACE
#     config        Tool/project configuration
#     doc           Documentation (markdown)
#     generated     Generated files
#     lib           Library code (not directly executable)
#     lock          Lock files
#     mise-task     Mise task scripts (implies executable)
#     script        Utility scripts (implies executable)
#     source        Source code
#
#   Language/filetype tags:
#     clojure, cue, go, java, json, python, shell, toml, typescript, yaml
#
#   Ecosystem tags:
#     bazel, docker, git, mise

# Tags that imply the file must be executable.
_EXECUTABLE_TAGS = ["script", "mise-task"]

def tagged_file(name, src, tags = []):
    """Tag a file with metadata.

    Args:
        name: Target name.
        src: Source file to tag.
        tags: List of tags. "script" and "mise-task" imply "executable".
    """

    effective_tags = list(tags)
    if "executable" not in effective_tags:
        for t in _EXECUTABLE_TAGS:
            if t in effective_tags:
                effective_tags.append("executable")
                break

    native.filegroup(
        name = name,
        srcs = [src],
        tags = effective_tags + ["tagged"],
    )
```

### `m/BUILD.bazel`

```starlark
exports_files(["tagged.bzl"])
```

---

## 5. Helpers: `m/helpers/bazel.cue`

CUE helpers for rendering Bazel rules in Midas interface templates. These
are only needed once you start creating Midas interfaces, but including
them in the skeleton avoids a follow-up structural change.

```cue
@experiment(aliasv2,explicitopen,try)

// bazel.cue -- standalone helpers for rendering Bazel BUILD.bazel rules.
//
// Used by Midas brick templates:
//   import "<your-cue-module>/m/helpers"
//   (helpers.TaggedFile & {src: "foo.go", tags: ["go", "source"]}).out
//
// This package must not import anything outside CUE stdlib.
// Uses public fields (not _hidden) because CUE hidden fields are
// package-scoped and cannot be unified across import boundaries.
package helpers

import "strings"

// TaggedFile renders a tagged_file() Bazel rule.
TaggedFile: {
	src: string
	tags: [...string]
	out: "tagged_file(\n    name = \"" + strings.ToLower(strings.Replace(src, ".", "_", -1)) + "_tag\",\n    src = \"" + src + "\",\n    tags = [\n" + strings.Join([for t in tags {"        \"" + t + "\","}], "\n") + "\n    ],\n)"
}

// BuildBazelTag is the tagged_file for BUILD.bazel itself.
BuildBazelTag: (TaggedFile & {src: "BUILD.bazel", tags: ["bazel", "bazel-build"]}).out
```

When the repo adds a format testing macro (like `fmt_test`), extend this
file with a `FmtTest` helper following the same pattern.

### `m/helpers/BUILD.bazel`

```starlark
load("//path/to/cue:cue.bzl", "cue_eval_test")

cue_eval_test(
    name = "cue_eval",
)
```

---

## 6. Adding a Midas Interface (When Ready)

Do this after you have classified directories and identified two or more
components that share enough structure to justify template generation.

### Create `m/interface/<name>/templates.cue`

A CUE file with `@tag()` parameters that renders output files:

```cue
@experiment(aliasv2,explicitopen,try)

import (
	"strings"
	"<your-cue-module>/m/helpers"
)

_name: string @tag(name)

// Each output file gets its own top-level field.
build_bazel: strings.Join(_sections, "\n\n")

_sections: [
	_bz_header,
	_bz_loads,
	_bz_library,
	helpers.BuildBazelTag,
]

_bz_header: "\"\"\"Generated by interface/<name>.\"\"\""

_bz_loads: """
	load("@io_bazel_rules_go//go:def.bzl", "go_library")
	load("//m:tagged.bzl", "tagged_file")
	"""

_bz_library: "go_library(\n    name = \"" + _name + "\",\n    ...\n)"
```

### Create `m/interface/<name>/BUILD.bazel`

```starlark
load("//path/to/cue:cue.bzl", "cue_eval_test")

exports_files(["templates.cue"])

cue_eval_test(
    name = "cue_eval",
)
```

### Register in `m/catalog/bricks.cue`

```cue
"interface/<name>": {
	path:        "interface/<name>"
	kind:        "interface"
	desc:        "description of what this interface stamps"
	midas:       true
	stamping:    "generator"
	catalog_key: "<name>_bricks"
}
```

### Add derived query in `m/catalog/catalog.cue`

```cue
<name>_bricks: {for p, b in _components
	if b.implements == "interface/<name>" {(p): b}}
```

### Test the template

```bash
cue export ./m/interface/<name>/templates.cue -e build_bazel --out text \
  -t name=example
```

---

## 7. Verification

After creating the skeleton:

```bash
# CUE validation
cue vet ./m/schema/
cue vet ./m/catalog/

# Bazel build
bazelisk build //m/schema:... //m/catalog:... //m/helpers:...

# Bazel test
bazelisk test //m/schema:cue_eval //m/catalog:cue_eval //m/helpers:cue_eval

# Query tagged files (once directories adopt tagged_file)
bazelisk query 'attr(tags, "\\btagged\\b", //...)'

# List all bricks by kind
cue eval ./m/catalog/ -e kit_bricks
cue eval ./m/catalog/ -e component_bricks
cue eval ./m/catalog/ -e interface_bricks
cue eval ./m/catalog/ -e relationship_bricks
```

---

## 8. What NOT to Do Yet

- **Do not create all interfaces at once.** Start with classification only.
  Add Midas interfaces one at a time as the stamping need becomes clear.

- **Do not aim for 100% coverage.** Classify the directories you actively
  work in. Let coverage grow organically as directories are touched.

- **Do not build the generator pipeline.** Stamping from templates requires
  a code generator (Go or babashka) that reads the catalog, evaluates CUE
  templates, and writes files. This is a significant piece of infrastructure.
  Start by proving that `cue export` on a template produces correct output,
  then build the generator.

- **Do not add `fmt_test` or format checking.** This requires a version-pinning
  system for formatter tools. Add it later as a separate concern.

- **Do not add executable permission tests.** The `tagged_file` macro can
  generate `sh_test` rules verifying `+x` permissions, but this requires a
  test script. Add it when the need arises.

---

## Summary

The skeleton is five packages:

| Package         | Purpose                       | Depends on  |
| --------------- | ----------------------------- | ----------- |
| `m/schema`      | Type definitions              | nothing     |
| `m/catalog`     | Directory inventory + queries | `m/schema`  |
| `m/helpers`     | BUILD.bazel rendering         | nothing     |
| `m/tagged.bzl`  | Bazel file tagging macro      | nothing     |
| `m/interface/*` | Midas templates (added later) | `m/helpers` |

Classification comes first. Stamping comes second. Generators come third.
Each layer is independently useful and independently verifiable.
