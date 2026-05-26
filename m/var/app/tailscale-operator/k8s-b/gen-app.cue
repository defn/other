@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: operator: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      "operator"
		namespace: "tailscale"
	}
}
objects: ServiceAccount: proxies: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      "proxies"
		namespace: "tailscale"
	}
}
objects: Role: operator: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		name:      "operator"
		namespace: "tailscale"
	}
	rules: [{
		apiGroups: [""]
		resources: [
			"secrets",
			"serviceaccounts",
			"configmaps",
		]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["pods/status"]
		verbs: ["update"]
	}, {
		apiGroups: ["apps"]
		resources: [
			"statefulsets",
			"deployments",
		]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"deletecollection",
		]
	}, {
		apiGroups: ["rbac.authorization.k8s.io"]
		resources: [
			"roles",
			"rolebindings",
		]
		verbs: [
			"get",
			"create",
			"patch",
			"update",
			"list",
			"watch",
			"deletecollection",
		]
	}, {
		apiGroups: ["monitoring.coreos.com"]
		resources: ["servicemonitors"]
		verbs: [
			"get",
			"list",
			"update",
			"create",
			"delete",
		]
	}]
}
objects: Role: proxies: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		name:      "proxies"
		namespace: "tailscale"
	}
	rules: [{
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
			"get",
		]
	}]
}
objects: ClusterRole: "tailscale-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "tailscale-operator"
	rules: [{
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: [
			"events",
			"services",
			"services/status",
		]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["networking.k8s.io"]
		resources: [
			"ingresses",
			"ingresses/status",
		]
		verbs: [
			"create",
			"delete",
			"deletecollection",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["networking.k8s.io"]
		resources: ["ingressclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["tailscale.com"]
		resources: [
			"connectors",
			"connectors/status",
			"proxyclasses",
			"proxyclasses/status",
			"proxygroups",
			"proxygroups/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["tailscale.com"]
		resources: [
			"dnsconfigs",
			"dnsconfigs/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["tailscale.com"]
		resources: [
			"tailnets",
			"tailnets/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["tailscale.com"]
		resources: [
			"proxygrouppolicies",
			"proxygrouppolicies/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["tailscale.com"]
		resources: [
			"recorders",
			"recorders/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["apiextensions.k8s.io"]
		resourceNames: ["servicemonitors.monitoring.coreos.com"]
		resources: ["customresourcedefinitions"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["admissionregistration.k8s.io"]
		resources: [
			"validatingadmissionpolicies",
			"validatingadmissionpolicybindings",
		]
		verbs: [
			"list",
			"create",
			"delete",
			"update",
			"get",
			"watch",
		]
	}]
}
objects: RoleBinding: operator: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		name:      "operator"
		namespace: "tailscale"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "operator"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "operator"
		namespace: "tailscale"
	}]
}
objects: RoleBinding: proxies: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		name:      "proxies"
		namespace: "tailscale"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "proxies"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "proxies"
		namespace: "tailscale"
	}]
}
objects: ClusterRoleBinding: "tailscale-operator": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "tailscale-operator"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "tailscale-operator"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "operator"
		namespace: "tailscale"
	}]
}
objects: Deployment: operator: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      "operator"
		namespace: "tailscale"
	}
	spec: {
		replicas: 1
		selector: matchLabels: app: "operator"
		strategy: type: "Recreate"
		template: {
			metadata: labels: app: "operator"
			spec: {
				containers: [{
					env: [{
						name:  "OPERATOR_INITIAL_TAGS"
						value: "tag:k8s-operator"
					}, {
						name:  "OPERATOR_HOSTNAME"
						value: "tailscale-operator"
					}, {
						name:  "OPERATOR_SECRET"
						value: "operator"
					}, {
						name:  "OPERATOR_LOGGING"
						value: "info"
					}, {
						name: "OPERATOR_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "OPERATOR_LOGIN_SERVER"
						value: null
					}, {
						name:  "OPERATOR_INGRESS_CLASS_NAME"
						value: "tailscale"
					}, {
						name:  "CLIENT_ID_FILE"
						value: "/oauth/client_id"
					}, {
						name:  "CLIENT_SECRET_FILE"
						value: "/oauth/client_secret"
					}, {
						name:  "PROXY_IMAGE"
						value: "tailscale/tailscale:v1.98.3"
					}, {
						name:  "PROXY_TAGS"
						value: "tag:k8s"
					}, {
						name:  "APISERVER_PROXY"
						value: "false"
					}, {
						name:  "PROXY_FIREWALL_MODE"
						value: "auto"
					}, {
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "POD_UID"
						valueFrom: fieldRef: fieldPath: "metadata.uid"
					}]
					image:           "host.k3d.internal:5000/mirror/tailscale/k8s-operator:v1.94.2"
					imagePullPolicy: "Always"
					name:            "operator"
					volumeMounts: [{
						mountPath: "/oauth"
						name:      "oauth"
						readOnly:  true
					}]
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				serviceAccountName: "operator"
				volumes: [{
					name: "oauth"
					secret: secretName: "operator-oauth"
				}]
			}
		}
	}
}
objects: IngressClass: tailscale: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "IngressClass"
	metadata: name:   "tailscale"
	spec: controller: "tailscale.com/ts-ingress"
}
