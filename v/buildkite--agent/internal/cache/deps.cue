@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/version",
	"@com_github_buildkite_zstash//:zstash",
	"@com_github_buildkite_zstash//api",
	"@com_github_buildkite_zstash//cache",
	"@com_github_dustin_go_humanize//:go-humanize",
	"@in_gopkg_yaml_v3//:yaml_v3",
]
