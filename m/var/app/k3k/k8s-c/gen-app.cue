@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: k3k: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "k3k"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "k3k"
			"app.kubernetes.io/version":    "v1.1.0"
			"helm.sh/chart":                "k3k-1.1.0"
		}
		name:      "k3k"
		namespace: "k3k"
	}
}
objects: ClusterRole: "k3k-kubelet-node": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "k3k-kubelet-node"
	rules: [{
		apiGroups: [""]
		resources: [
			"nodes",
			"nodes/proxy",
			"namespaces",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "k3k-priorityclass": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "k3k-priorityclass"
	rules: [{
		apiGroups: ["scheduling.k8s.io"]
		resources: ["priorityclasses"]
		verbs: ["*"]
	}]
}
objects: ClusterRoleBinding: k3k: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "k3k"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "k3k"
			"app.kubernetes.io/version":    "v1.1.0"
			"helm.sh/chart":                "k3k-1.1.0"
		}
		name: "k3k"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "cluster-admin"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "k3k"
		namespace: "k3k"
	}]
}
objects: ClusterRoleBinding: "k3k-kubelet-node": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "k3k-kubelet-node"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "k3k-kubelet-node"
	}
}
objects: ClusterRoleBinding: "k3k-priorityclass": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "k3k-priorityclass"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "k3k-priorityclass"
	}
}
objects: Deployment: k3k: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "k3k"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "k3k"
			"app.kubernetes.io/version":    "v1.1.0"
			"helm.sh/chart":                "k3k-1.1.0"
		}
		name:      "k3k"
		namespace: "k3k"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "k3k"
			"app.kubernetes.io/name":     "k3k"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/instance": "k3k"
				"app.kubernetes.io/name":     "k3k"
			}
			spec: {
				containers: [{
					args: [
						"k3k",
						"--cluster-cidr=",
						"--k3s-server-image=rancher/k3s",
						"--k3s-server-image-pull-policy=",
						"--agent-shared-image=rancher/k3k-kubelet:v1.1.0",
						"--agent-shared-image-pull-policy=",
						"--agent-virtual-image=rancher/k3s",
						"--agent-virtual-image-pull-policy=",
						"--kubelet-port-range=50000-51000",
					]
					env: [{
						name: "CONTROLLER_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}]
					image:           "host.k3d.internal:5000/mirror/rancher/k3k:v1.1.0"
					imagePullPolicy: null
					name:            "k3k"
					ports: [{
						containerPort: 8080
						name:          "https"
						protocol:      "TCP"
					}]
				}]
				imagePullSecrets: []
				serviceAccountName: "k3k"
			}
		}
	}
}
