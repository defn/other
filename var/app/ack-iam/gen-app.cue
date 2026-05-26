@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "ack-iam-controller": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-controller"
		namespace: "ack-system"
	}
}
objects: Role: "ack-iam-iam-chart-configmaps-cache": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-iam-chart-configmaps-cache"
		namespace: "ack-system"
	}
	rules: [{
		apiGroups: [""]
		resources: ["configmaps"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: Role: "ack-iam-iam-chart-reader": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		creationTimestamp: null
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-iam-chart-reader"
		namespace: "ack-system"
	}
	rules: [{
		apiGroups: ["iam.services.k8s.aws"]
		resources: [
			"groups",
			"instanceprofiles",
			"openidconnectproviders",
			"policies",
			"roles",
			"servicelinkedroles",
			"users",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: Role: "ack-iam-iam-chart-writer": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		creationTimestamp: null
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-iam-chart-writer"
		namespace: "ack-system"
	}
	rules: [{
		apiGroups: ["iam.services.k8s.aws"]
		resources: [
			"groups",
			"instanceprofiles",
			"openidconnectproviders",
			"policies",
			"roles",
			"servicelinkedroles",
			"users",
		]
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
		apiGroups: ["iam.services.k8s.aws"]
		resources: [
			"groups",
			"instanceprofiles",
			"openidconnectproviders",
			"policies",
			"roles",
			"servicelinkedroles",
			"users",
		]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}]
}
objects: ClusterRole: "ack-iam-iam-chart": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name: "ack-iam-iam-chart"
	}
	rules: [{
		apiGroups: [""]
		resources: [
			"configmaps",
			"secrets",
		]
		verbs: [
			"get",
			"list",
			"patch",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["namespaces"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["iam.services.k8s.aws"]
		resources: [
			"groups",
			"instanceprofiles",
			"openidconnectproviders",
			"policies",
			"roles",
			"servicelinkedroles",
			"users",
		]
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
		apiGroups: ["iam.services.k8s.aws"]
		resources: [
			"groups/status",
			"instanceprofiles/status",
			"openidconnectproviders/status",
			"policies/status",
			"roles/status",
			"servicelinkedroles/status",
			"users/status",
		]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}, {
		apiGroups: ["services.k8s.aws"]
		resources: [
			"fieldexports",
			"iamroleselectors",
		]
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
		apiGroups: ["services.k8s.aws"]
		resources: [
			"fieldexports/status",
			"iamroleselectors/status",
		]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}]
}
objects: ClusterRole: "ack-iam-iam-chart-namespaces-cache": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name: "ack-iam-iam-chart-namespaces-cache"
	}
	rules: [{
		apiGroups: [""]
		resources: ["namespaces"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: RoleBinding: "ack-iam-iam-chart-configmaps-cache": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-iam-chart-configmaps-cache"
		namespace: "ack-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "ack-iam-iam-chart-configmaps-cache"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "ack-iam-controller"
		namespace: "ack-system"
	}]
}
objects: ClusterRoleBinding: "ack-iam-iam-chart-namespaces-cache": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name: "ack-iam-iam-chart-namespaces-cache"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "ack-iam-iam-chart-namespaces-cache"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "ack-iam-controller"
		namespace: "ack-system"
	}]
}
objects: ClusterRoleBinding: "ack-iam-iam-chart-rolebinding": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name: "ack-iam-iam-chart-rolebinding"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "ack-iam-iam-chart"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "ack-iam-controller"
		namespace: "ack-system"
	}]
}
objects: Deployment: "ack-iam-iam-chart": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "ack-iam"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "iam-chart"
			"app.kubernetes.io/version":    "1.6.4"
			"helm.sh/chart":                "iam-chart-1.6.4"
			"k8s-app":                      "iam-chart"
		}
		name:      "ack-iam-iam-chart"
		namespace: "ack-system"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "ack-iam"
			"app.kubernetes.io/name":     "iam-chart"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/instance":   "ack-iam"
				"app.kubernetes.io/managed-by": "Helm"
				"app.kubernetes.io/name":       "iam-chart"
				"k8s-app":                      "iam-chart"
			}
			spec: {
				containers: [{
					args: [
						"--aws-region",
						"$(AWS_REGION)",
						"--aws-endpoint-url",
						"$(AWS_ENDPOINT_URL)",
						"--log-level",
						"$(ACK_LOG_LEVEL)",
						"--resource-tags",
						"$(ACK_RESOURCE_TAGS)",
						"--watch-namespace",
						"$(ACK_WATCH_NAMESPACE)",
						"--watch-selectors",
						"$(ACK_WATCH_SELECTORS)",
						"--reconcile-resources",
						"$(RECONCILE_RESOURCES)",
						"--deletion-policy",
						"$(DELETION_POLICY)",
						"--reconcile-default-resync-seconds",
						"$(RECONCILE_DEFAULT_RESYNC_SECONDS)",
						"--reconcile-default-max-concurrent-syncs",
						"$(RECONCILE_DEFAULT_MAX_CONCURRENT_SYNCS)",
						"--feature-gates",
						"$(FEATURE_GATES)",
						"--enable-carm=true",
					]
					command: ["./bin/controller"]
					env: [{
						name: "ACK_SYSTEM_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "AWS_REGION"
						value: null
					}, {
						name:  "AWS_ENDPOINT_URL"
						value: ""
					}, {
						name:  "AWS_IDENTITY_ENDPOINT_URL"
						value: ""
					}, {
						name:  "ACK_WATCH_NAMESPACE"
						value: null
					}, {
						name:  "ACK_WATCH_SELECTORS"
						value: null
					}, {
						name:  "RECONCILE_RESOURCES"
						value: "Group,InstanceProfile,OpenIDConnectProvider,Policy,Role,ServiceLinkedRole,User"
					}, {
						name:  "DELETION_POLICY"
						value: "delete"
					}, {
						name:  "LEADER_ELECTION_NAMESPACE"
						value: ""
					}, {
						name:  "ACK_LOG_LEVEL"
						value: "info"
					}, {
						name:  "ACK_RESOURCE_TAGS"
						value: "services.k8s.aws/controller-version=%CONTROLLER_SERVICE%-%CONTROLLER_VERSION%,services.k8s.aws/namespace=%K8S_NAMESPACE%,app.kubernetes.io/managed-by=%MANAGED_BY%,kro.run/kro-version=%KRO_VERSION%"
					}, {
						name:  "RECONCILE_DEFAULT_RESYNC_SECONDS"
						value: "36000"
					}, {
						name:  "RECONCILE_DEFAULT_MAX_CONCURRENT_SYNCS"
						value: "1"
					}, {
						name:  "FEATURE_GATES"
						value: "IAMRoleSelector=false,ReadOnlyResources=true,ResourceAdoption=true,ServiceLevelCARM=false,TeamLevelCARM=false"
					}]
					image:           "host.k3d.internal:5000/mirror/public.ecr.aws/aws-controllers-k8s/iam-controller:1.6.4"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/healthz"
							port: 8081
						}
						initialDelaySeconds: 15
						periodSeconds:       20
					}
					name: "controller"
					ports: [{
						containerPort: 8080
						name:          "http"
					}]
					readinessProbe: {
						httpGet: {
							path: "/readyz"
							port: 8081
						}
						initialDelaySeconds: 5
						periodSeconds:       10
					}
					resources: {
						limits: {
							cpu:    "100m"
							memory: "128Mi"
						}
						requests: {
							cpu:    "50m"
							memory: "64Mi"
						}
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
					}
				}]
				dnsPolicy:   "ClusterFirst"
				hostIPC:     false
				hostNetwork: false
				hostPID:     false
				nodeSelector: "kubernetes.io/os": "linux"
				securityContext: seccompProfile: type: "RuntimeDefault"
				serviceAccountName:            "ack-iam-controller"
				terminationGracePeriodSeconds: 10
			}
		}
	}
}
