@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/internal/experiments",
	"//v/buildkite--agent/logger",
	"@com_github_creack_pty//:pty",
	"@org_golang_x_sys//unix",
	"@org_golang_x_term//:term",
]
