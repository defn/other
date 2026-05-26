@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "arc-gha-rs-controller": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "arc"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "gha-rs-controller"
			"app.kubernetes.io/namespace":  "arc-systems"
			"app.kubernetes.io/part-of":    "gha-rs-controller"
			"app.kubernetes.io/version":    "0.14.2"
			"helm.sh/chart":                "gha-rs-controller-0.14.2"
		}
		name:      "arc-gha-rs-controller"
		namespace: "arc-systems"
	}
}
objects: Role: "arc-gha-rs-controller-listener": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		name:      "arc-gha-rs-controller-listener"
		namespace: "arc-systems"
	}
	rules: [{
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"create",
			"delete",
			"get",
		]
	}, {
		apiGroups: [""]
		resources: ["pods/status"]
		verbs: ["get"]
	}, {
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"create",
			"delete",
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["serviceaccounts"]
		verbs: [
			"create",
			"delete",
			"get",
			"patch",
			"update",
		]
	}]
}
objects: ClusterRole: "arc-gha-rs-controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "arc-gha-rs-controller"
	rules: [{
		apiGroups: ["actions.github.com"]
		resources: ["autoscalingrunnersets"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["autoscalingrunnersets/finalizers"]
		verbs: [
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["autoscalingrunnersets/status"]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["autoscalinglisteners"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["autoscalinglisteners/status"]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["autoscalinglisteners/finalizers"]
		verbs: [
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunnersets"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunnersets/status"]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunnersets/finalizers"]
		verbs: [
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunners"]
		verbs: [
			"create",
			"delete",
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunners/finalizers"]
		verbs: [
			"patch",
			"update",
		]
	}, {
		apiGroups: ["actions.github.com"]
		resources: ["ephemeralrunners/status"]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["serviceaccounts"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["rbac.authorization.k8s.io"]
		resources: ["rolebindings"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["rbac.authorization.k8s.io"]
		resources: ["roles"]
		verbs: [
			"list",
			"watch",
			"patch",
		]
	}]
}
objects: RoleBinding: "arc-gha-rs-controller-listener": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		name:      "arc-gha-rs-controller-listener"
		namespace: "arc-systems"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "arc-gha-rs-controller-listener"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "arc-gha-rs-controller"
		namespace: "arc-systems"
	}]
}
objects: ClusterRoleBinding: "arc-gha-rs-controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "arc-gha-rs-controller"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "arc-gha-rs-controller"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "arc-gha-rs-controller"
		namespace: "arc-systems"
	}]
}
objects: Deployment: "arc-gha-rs-controller": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"actions.github.com/controller-service-account-name":      "arc-gha-rs-controller"
			"actions.github.com/controller-service-account-namespace": "arc-systems"
			"app.kubernetes.io/instance":                              "arc"
			"app.kubernetes.io/managed-by":                            "Helm"
			"app.kubernetes.io/name":                                  "gha-rs-controller"
			"app.kubernetes.io/namespace":                             "arc-systems"
			"app.kubernetes.io/part-of":                               "gha-rs-controller"
			"app.kubernetes.io/version":                               "0.14.2"
			"helm.sh/chart":                                           "gha-rs-controller-0.14.2"
		}
		name:      "arc-gha-rs-controller"
		namespace: "arc-systems"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance":  "arc"
			"app.kubernetes.io/name":      "gha-rs-controller"
			"app.kubernetes.io/namespace": "arc-systems"
		}
		template: {
			metadata: {
				annotations: "kubectl.kubernetes.io/default-container": "manager"
				labels: {
					"app.kubernetes.io/component": "controller-manager"
					"app.kubernetes.io/instance":  "arc"
					"app.kubernetes.io/name":      "gha-rs-controller"
					"app.kubernetes.io/namespace": "arc-systems"
					"app.kubernetes.io/part-of":   "gha-rs-controller"
					"app.kubernetes.io/version":   "0.14.2"
				}
			}
			spec: {
				containers: [{
					args: [
						"--auto-scaling-runner-set-only",
						"--log-level=debug",
						"--log-format=text",
						"--runner-max-concurrent-reconciles=2",
						"--update-strategy=immediate",
						"--listener-metrics-addr=0",
						"--listener-metrics-endpoint=",
						"--metrics-addr=0",
					]
					command: ["/manager"]
					env: [{
						name:  "CONTROLLER_MANAGER_CONTAINER_IMAGE"
						value: "ghcr.io/actions/gha-runner-scale-set-controller:0.14.2"
					}, {
						name: "CONTROLLER_MANAGER_POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}]
					image:           "host.k3d.internal:5000/mirror/ghcr.io/actions/gha-runner-scale-set-controller:0.14.2"
					imagePullPolicy: "IfNotPresent"
					name:            "manager"
					volumeMounts: [{
						mountPath: "/tmp"
						name:      "tmp"
					}]
				}]
				serviceAccountName:            "arc-gha-rs-controller"
				terminationGracePeriodSeconds: 10
				volumes: [{
					emptyDir: {}
					name: "tmp"
				}]
			}
		}
	}
}
