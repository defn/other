@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: riverqueue (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: riverqueue: {
	name: "riverqueue"
	kind: "raw"
	path: "tenant/library/app/riverqueue"
	desc: "River Queue PostgreSQL database and web UI"
}
