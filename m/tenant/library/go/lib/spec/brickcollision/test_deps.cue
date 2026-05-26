@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@com_github_rogpeppe_go_internal//testscript",
]

test_data: [
	"testdata/01_empty.txtar",
	"testdata/02_single_brick.txtar",
	"testdata/03_disjoint_writes.txtar",
	"testdata/04_simple_collision.txtar",
	"testdata/05_multi_path_same_pair.txtar",
	"testdata/06_ancestor_pair_skipped.txtar",
	"testdata/07_ancestor_skipped_either_direction.txtar",
	"testdata/08_multi_pair_collisions.txtar",
	"testdata/09_three_way_collision.txtar",
	"testdata/10_mixed_ancestor_and_sibling.txtar",
	"testdata/11_path_prefix_match_not_strict_ancestor.txtar",
	"testdata/12_partial_overlap_disjoint_remainder.txtar",
	"testdata/13_duplicate_path_within_brick.txtar",
]
