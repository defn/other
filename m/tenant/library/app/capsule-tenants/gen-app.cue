@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ConfigMap: "capsule-tenants": {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "capsule-tenants"
		namespace: "capsule"
	}
	data: managed: "true"
}
objects: Tenant: infra: {
	apiVersion: "capsule.clastix.io/v1beta2"
	kind:       "Tenant"
	metadata: name: "infra"
	spec: {
		cordoned:        false
		preventDeletion: false
		owners: [{
			name: "system:serviceaccount:argocd:argocd-application-controller"
			kind: "ServiceAccount"
			clusterRoles: [
				"admin",
				"capsule-namespace-deleter",
			]
		}]
	}
}
