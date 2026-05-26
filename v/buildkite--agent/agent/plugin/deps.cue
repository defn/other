@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/env",
	"@com_github_buildkite_go_pipeline//ordered",
	"@com_github_qri_io_jsonschema//:jsonschema",
	"@in_gopkg_yaml_v3//:yaml_v3",
]
