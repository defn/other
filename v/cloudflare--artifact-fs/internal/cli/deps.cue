@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/cloudflare--artifact-fs/internal/daemon:daemon",
	"//v/cloudflare--artifact-fs/internal/logging:logging",
	"//v/cloudflare--artifact-fs/internal/model:model",
	"@com_github_urfave_cli//:cli",
]
