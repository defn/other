@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/cloudflare--artifact-fs/internal/auth:auth",
	"//v/cloudflare--artifact-fs/internal/fusefs:fusefs",
	"//v/cloudflare--artifact-fs/internal/gitstore:gitstore",
	"//v/cloudflare--artifact-fs/internal/hydrator:hydrator",
	"//v/cloudflare--artifact-fs/internal/meta:meta",
	"//v/cloudflare--artifact-fs/internal/model:model",
	"//v/cloudflare--artifact-fs/internal/overlay:overlay",
	"//v/cloudflare--artifact-fs/internal/registry:registry",
	"//v/cloudflare--artifact-fs/internal/snapshot:snapshot",
	"//v/cloudflare--artifact-fs/internal/watcher:watcher",
]
