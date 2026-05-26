@experiment(aliasv2,explicitopen,shortcircuit,try)

// App instance: capsule-tenants (library tenant).
//
// Per-app catalog shard per AIDR-00083 (leaves-into-branches).
package catalog

apps: "capsule-tenants": {
	name: "capsule-tenants"
	kind: "raw"
	path: "tenant/library/app/capsule-tenants"
	desc: "Capsule Tenant definitions for infra namespaces"
}
