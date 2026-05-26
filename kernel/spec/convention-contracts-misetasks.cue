@experiment(aliasv2,explicitopen,shortcircuit,try)

// Convention-contract shard: misetasks.
//
// One of multiple convention-contracts-*.cue shards per AIDR-00083;
// sharded to enable parallel-write safety when bricks claim
// conventions concurrently. Helper struct fields and the `bricks`
// schema binding stay in convention-contracts.cue and are
// available to all shards via CUE package unification.

package contracts

// Self-claim: the shard file itself is hand-written.
_manualFileShards: "convention-contracts-misetasks": [
	"kernel/spec/convention-contracts-misetasks.cue",
]

// ---- aidr/ -- NNNNN-<slug>.md --------------------------------------

// aidr generator moved to convention-contracts-aidr.cue (AIDR-00083
// sharding). Future per-contract shards follow the same pattern:
// convention-contracts-<name>.cue.

// ---- .mise/tasks/ -- <task-name>.clj --------------------------------

generators: misetasks: {
	generator: "misetasks"
	source:    "(convention-based; no Go generator)"
	reason:    "mise task scripts under .mise/tasks/ follow the <name>.clj convention (kebab-case). A file named MyTask.CLJ or task.sh in this dir would orphan, which catches naming mistakes."
	read_from: {
		lattice: ["tree.dirs.m.dirs[\".mise\"].dirs.tasks"]
	}
	related_aidr: [62, 66]
	paths: [
		for name, f in tree.dirs.m.dirs[".mise"].dirs.tasks.files
		if f.type == "file"
		if name =~ "^[a-z][a-z0-9-]*\\.clj$" {".mise/tasks/\(name)"},
	]
}
