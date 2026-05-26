@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@com_github_rogpeppe_go_internal//testscript",
]

test_data: [
	"testdata/01_empty.txtar",
	"testdata/02_single_brick.txtar",
	"testdata/03_disjoint_writes.txtar",
	"testdata/04_brick_a_reads_brick_b_writes.txtar",
	"testdata/05_brick_a_writes_brick_b_reads.txtar",
	"testdata/06_transitive_three_bricks.txtar",
	"testdata/07_glob_matches_concrete_write.txtar",
	"testdata/08_glob_matches_nothing.txtar",
	"testdata/09_multiple_intersections_same_pair.txtar",
	"testdata/10_self_loop_skipped.txtar",
	"testdata/11_ancestor_pair_skipped.txtar",
	"testdata/12_determinism.txtar",
]
