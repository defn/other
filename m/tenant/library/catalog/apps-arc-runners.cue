@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: arc-runners (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "arc-runners": {
	name: "arc-runners"
	kind: "raw"
	path: "tenant/library/app/arc-runners"
	desc: "GitHub Actions runner scale sets"
}
