@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "argo-rollouts": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name:      "argo-rollouts"
		namespace: "argo-rollouts"
	}
}
objects: ClusterRole: "argo-rollouts": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name: "argo-rollouts"
	}
	rules: [{
		apiGroups: ["argoproj.io"]
		resources: [
			"rollouts",
			"rollouts/status",
			"rollouts/finalizers",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["argoproj.io"]
		resources: [
			"analysisruns",
			"analysisruns/finalizers",
			"experiments",
			"experiments/finalizers",
		]
		verbs: [
			"create",
			"get",
			"list",
			"watch",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: ["argoproj.io"]
		resources: [
			"analysistemplates",
			"clusteranalysistemplates",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["apps"]
		resources: ["replicasets"]
		verbs: [
			"create",
			"get",
			"list",
			"watch",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [
			"",
			"apps",
		]
		resources: [
			"deployments",
			"podtemplates",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["services"]
		verbs: [
			"get",
			"list",
			"watch",
			"patch",
			"create",
			"delete",
		]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"create",
			"get",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["configmaps"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"list",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods/eviction"]
		verbs: ["create"]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"update",
			"patch",
		]
	}, {
		apiGroups: [
			"networking.k8s.io",
			"extensions",
		]
		resources: ["ingresses"]
		verbs: [
			"create",
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["batch"]
		resources: ["jobs"]
		verbs: [
			"create",
			"get",
			"list",
			"watch",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: ["networking.istio.io"]
		resources: [
			"virtualservices",
			"destinationrules",
		]
		verbs: [
			"watch",
			"get",
			"update",
			"patch",
			"list",
		]
	}, {
		apiGroups: ["split.smi-spec.io"]
		resources: ["trafficsplits"]
		verbs: [
			"create",
			"watch",
			"get",
			"update",
			"patch",
		]
	}, {
		apiGroups: [
			"getambassador.io",
			"x.getambassador.io",
		]
		resources: [
			"mappings",
			"ambassadormappings",
		]
		verbs: [
			"create",
			"watch",
			"get",
			"update",
			"list",
			"delete",
		]
	}, {
		apiGroups: [""]
		resources: ["endpoints"]
		verbs: ["get"]
	}, {
		apiGroups: ["elbv2.k8s.aws"]
		resources: ["targetgroupbindings"]
		verbs: [
			"list",
			"get",
		]
	}, {
		apiGroups: ["appmesh.k8s.aws"]
		resources: ["virtualservices"]
		verbs: [
			"watch",
			"get",
			"list",
		]
	}, {
		apiGroups: ["appmesh.k8s.aws"]
		resources: [
			"virtualnodes",
			"virtualrouters",
		]
		verbs: [
			"watch",
			"get",
			"list",
			"update",
			"patch",
		]
	}, {
		apiGroups: [
			"traefik.containo.us",
			"traefik.io",
		]
		resources: ["traefikservices"]
		verbs: [
			"watch",
			"get",
			"update",
		]
	}, {
		apiGroups: ["apisix.apache.org"]
		resources: ["apisixroutes"]
		verbs: [
			"watch",
			"get",
			"update",
		]
	}, {
		apiGroups: ["projectcontour.io"]
		resources: ["httpproxies"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["networking.gloo.solo.io"]
		resources: ["routetables"]
		verbs: ["*"]
	}, {
		apiGroups: ["gateway.networking.k8s.io"]
		resources: [
			"httproutes",
			"tcproutes",
			"tlsroutes",
			"udproutes",
			"grpcroutes",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}]
}
objects: ClusterRole: "argo-rollouts-aggregate-to-admin": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":                  "rollouts-controller"
			"app.kubernetes.io/instance":                   "argo-rollouts"
			"app.kubernetes.io/managed-by":                 "Helm"
			"app.kubernetes.io/name":                       "argo-rollouts"
			"app.kubernetes.io/part-of":                    "argo-rollouts"
			"app.kubernetes.io/version":                    "v1.9.0"
			"helm.sh/chart":                                "argo-rollouts-2.40.9"
			"rbac.authorization.k8s.io/aggregate-to-admin": "true"
		}
		name: "argo-rollouts-aggregate-to-admin"
	}
	rules: [{
		apiGroups: ["argoproj.io"]
		resources: [
			"rollouts",
			"rollouts/scale",
			"rollouts/status",
			"experiments",
			"analysistemplates",
			"clusteranalysistemplates",
			"analysisruns",
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
	}]
}
objects: ClusterRole: "argo-rollouts-aggregate-to-edit": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":                 "rollouts-controller"
			"app.kubernetes.io/instance":                  "argo-rollouts"
			"app.kubernetes.io/managed-by":                "Helm"
			"app.kubernetes.io/name":                      "argo-rollouts"
			"app.kubernetes.io/part-of":                   "argo-rollouts"
			"app.kubernetes.io/version":                   "v1.9.0"
			"helm.sh/chart":                               "argo-rollouts-2.40.9"
			"rbac.authorization.k8s.io/aggregate-to-edit": "true"
		}
		name: "argo-rollouts-aggregate-to-edit"
	}
	rules: [{
		apiGroups: ["argoproj.io"]
		resources: [
			"rollouts",
			"rollouts/scale",
			"rollouts/status",
			"experiments",
			"analysistemplates",
			"clusteranalysistemplates",
			"analysisruns",
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
	}]
}
objects: ClusterRole: "argo-rollouts-aggregate-to-view": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/component":                 "rollouts-controller"
			"app.kubernetes.io/instance":                  "argo-rollouts"
			"app.kubernetes.io/managed-by":                "Helm"
			"app.kubernetes.io/name":                      "argo-rollouts"
			"app.kubernetes.io/part-of":                   "argo-rollouts"
			"app.kubernetes.io/version":                   "v1.9.0"
			"helm.sh/chart":                               "argo-rollouts-2.40.9"
			"rbac.authorization.k8s.io/aggregate-to-view": "true"
		}
		name: "argo-rollouts-aggregate-to-view"
	}
	rules: [{
		apiGroups: ["argoproj.io"]
		resources: [
			"rollouts",
			"rollouts/scale",
			"experiments",
			"analysistemplates",
			"clusteranalysistemplates",
			"analysisruns",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRoleBinding: "argo-rollouts": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name: "argo-rollouts"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "argo-rollouts"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "argo-rollouts"
		namespace: "argo-rollouts"
	}]
}
objects: ConfigMap: "argo-rollouts-config": {
	apiVersion: "v1"
	data:       null
	kind:       "ConfigMap"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name:      "argo-rollouts-config"
		namespace: "argo-rollouts"
	}
}
objects: ConfigMap: "argo-rollouts-notification-configmap": {
	apiVersion: "v1"
	data:       null
	kind:       "ConfigMap"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name:      "argo-rollouts-notification-configmap"
		namespace: "argo-rollouts"
	}
}
objects: Deployment: "argo-rollouts": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "rollouts-controller"
			"app.kubernetes.io/instance":   "argo-rollouts"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "argo-rollouts"
			"app.kubernetes.io/part-of":    "argo-rollouts"
			"app.kubernetes.io/version":    "v1.9.0"
			"helm.sh/chart":                "argo-rollouts-2.40.9"
		}
		name:      "argo-rollouts"
		namespace: "argo-rollouts"
	}
	spec: {
		replicas:             2
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/component": "rollouts-controller"
			"app.kubernetes.io/instance":  "argo-rollouts"
			"app.kubernetes.io/name":      "argo-rollouts"
		}
		strategy: type: "RollingUpdate"
		template: {
			metadata: {
				annotations: "checksum/cm": "667b050f87d60d0f2528015eaf1d68d848de9c57a1cd40f1027d0353f62d7791"
				labels: {
					"app.kubernetes.io/component": "rollouts-controller"
					"app.kubernetes.io/instance":  "argo-rollouts"
					"app.kubernetes.io/name":      "argo-rollouts"
				}
			}
			spec: {
				containers: [{
					args: [
						"--healthzPort=8080",
						"--metricsport=8090",
						"--loglevel=info",
						"--logformat=text",
						"--kloglevel=0",
						"--leader-elect",
					]
					image:           "host.k3d.internal:5000/mirror/quay.io/argoproj/argo-rollouts:v1.9.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/healthz"
							port: "healthz"
						}
						initialDelaySeconds: 30
						periodSeconds:       20
						successThreshold:    1
						timeoutSeconds:      10
					}
					name: "argo-rollouts"
					ports: [{
						containerPort: 8090
						name:          "metrics"
					}, {
						containerPort: 8080
						name:          "healthz"
					}]
					readinessProbe: {
						failureThreshold: 3
						httpGet: {
							path: "/metrics"
							port: "metrics"
						}
						initialDelaySeconds: 15
						periodSeconds:       5
						successThreshold:    1
						timeoutSeconds:      4
					}
					resources: {}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/home/argo-rollouts/plugin-bin"
						name:      "plugin-bin"
					}, {
						mountPath: "/tmp"
						name:      "tmp"
					}]
				}]
				securityContext: runAsNonRoot: true
				serviceAccountName:            "argo-rollouts"
				terminationGracePeriodSeconds: 30
				volumes: [{
					emptyDir: {}
					name: "plugin-bin"
				}, {
					emptyDir: {}
					name: "tmp"
				}]
			}
		}
	}
}
