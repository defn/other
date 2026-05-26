@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

// Multi-instance configuration.
// Coder runs per-team in separate namespaces.
// Run `cue eval -c` to verify instance is concrete.

instance: {
	name:      string
	namespace: "coder-\(name)"
}

// Apply instance namespace to all namespaced resources.
// Cluster-scoped resources (ClusterRole, ClusterRoleBinding) are unaffected.
objects: ServiceAccount: coder: metadata: namespace:         instance.namespace
objects: Role: "coder-workspace-perms": metadata: namespace: instance.namespace
objects: RoleBinding: coder: metadata: namespace:            instance.namespace
objects: Service: coder: metadata: namespace:                instance.namespace
objects: Deployment: coder: metadata: namespace:             instance.namespace
