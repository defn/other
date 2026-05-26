@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/env",
	"//v/buildkite--agent/internal/olfactor",
	"//v/buildkite--agent/internal/shellscript",
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/process",
	"//v/buildkite--agent/tracetools",
	"@com_github_buildkite_shellwords//:shellwords",
	"@com_github_gofrs_flock//:flock",
	"@io_opentelemetry_go_otel//:otel",
	"@io_opentelemetry_go_otel//propagation",
	"@io_opentelemetry_go_otel_trace//:trace",
]
