@experiment(aliasv2,explicitopen,shortcircuit,try)

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
//                   (formerly named "kit" -- renamed per AIDR-00083:
//                   branches compute from leaves)
package schema

#BrickKind: "relationship" | "interface" | "component" | "branch"

// #StampingMethod describes how a Midas interface stamps out components.
//   - macro:     interface/{name}/{name}.bzl exists, components call it
//   - generator: defn gen stamps components via Go generator
#StampingMethod: "macro" | "generator"

#Brick: {
	path: string
	// slug is the catalog/brick-<slug>.cue filename suffix. Defaults to
	// the path with the leading "tenant/<tname>/" or "kernel/" prefix
	// stripped and "/" replaced by "--", giving filenames that survive
	// tenant moves (a bot at tenant/defn/bot/molly and the same bot at
	// tenant/<other>/bot/molly both slug to "bot--molly"). When two
	// bricks would default to the same slug, either MUST set slug
	// explicitly; CheckBricks asserts uniqueness.
	slug?: string
	kind:  #BrickKind
	desc?: string
	composes?: [...string]
	implements?: string
	parent?:     string // path of parent brick (collects children)
	stamp_type?: string // stamp type that created this brick (e.g. "go-cmd", "helm-app")

	// Midas fields -- required when midas is true.
	midas?:       bool
	stamping?:    #StampingMethod
	catalog_key?: string

	// Per-brick read/write fingerprint (AIDR-00096). Optional inline
	// declaration for hand-edited bricks or generator-stamped bricks
	// that touch files outside the path-prefix derivation. The
	// `brick_io` aggregation in contracts-schema.cue produces the
	// effective fingerprint by unioning these declarations with the
	// per-generator intersection of path/read_from over the brick's
	// path prefix. Hand-edited bricks (those whose path prefix is
	// not claimed by any generator) currently default to empty;
	// populating them is a follow-up to AIDR-00096.
	reads?: [...string]
	writes?: [...string]

	// `shared` marks a brick that the coordinator must merge itself
	// rather than dispatching to a parallel sub-agent. AIDR-00132's
	// partitioner uses this signal to omit shared bricks when
	// computing disjoint sub-agent groups: shared bricks become the
	// coordinator's queue, the rest fan out in parallel.
	//
	// Default behavior when unset: branch / relationship / interface
	// bricks are treated as shared by inference (they aggregate or
	// span). component bricks default to NOT shared. Set explicitly
	// to override -- e.g. a component catalog dir that many other
	// bricks read should declare `shared: true`.
	shared?: bool

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
