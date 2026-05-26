@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@com_github_rogpeppe_go_internal//testscript",
]

test_data: [
	"testdata/01_empty.txtar",
	"testdata/02_single_leaf.txtar",
	"testdata/03_two_leafs_clean.txtar",
	"testdata/04_profile_hardcode_violation.txtar",
	"testdata/05_path_hardcode_violation.txtar",
	"testdata/06_bare_name_violation.txtar",
	"testdata/07_library_reference_allowed.txtar",
	"testdata/08_generator_output_skipped.txtar",
	"testdata/09_comment_skipped.txtar",
	"testdata/10_catalog_borrow_allowed.txtar",
	"testdata/11_self_reference_allowed.txtar",
	"testdata/12_multiple_violations_sorted.txtar",
]
