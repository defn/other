@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/cloudflare--artifact-fs/internal/hydrator:hydrator",
	"//v/cloudflare--artifact-fs/internal/model:model",
	"@com_github_jacobsa_fuse//:fuse",
	"@com_github_jacobsa_fuse//fuseops:fuseops",
	"@com_github_jacobsa_fuse//fuseutil:fuseutil",
]
