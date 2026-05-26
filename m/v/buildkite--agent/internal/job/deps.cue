@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/agent/plugin",
	"//v/buildkite--agent/api",
	"//v/buildkite--agent/env",
	"//v/buildkite--agent/internal/experiments",
	"//v/buildkite--agent/internal/agenthttp",
	"//v/buildkite--agent/internal/file",
	"//v/buildkite--agent/internal/job/hook",
	"//v/buildkite--agent/internal/osutil",
	"//v/buildkite--agent/internal/redact",
	"//v/buildkite--agent/internal/replacer",
	"//v/buildkite--agent/internal/secrets",
	"//v/buildkite--agent/internal/self",
	"//v/buildkite--agent/internal/shell",
	"//v/buildkite--agent/internal/shellscript",
	"//v/buildkite--agent/internal/socket",
	"//v/buildkite--agent/internal/tempfile",
	"//v/buildkite--agent/jobapi",
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/process",
	"//v/buildkite--agent/tracetools",
	"//v/buildkite--agent/version",
	"@com_github_buildkite_go_pipeline//:go-pipeline",
	"@com_github_buildkite_roko//:roko",
	"@com_github_buildkite_shellwords//:shellwords",
	"@org_golang_x_crypto//ssh/knownhosts",
]
