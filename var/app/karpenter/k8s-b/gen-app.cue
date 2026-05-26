@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: karpenter: {
	apiVersion:                   "v1"
	automountServiceAccountToken: false
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
}
objects: Role: karpenter: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"watch",
		]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resourceNames: ["karpenter-leader-election"]
		resources: ["leases"]
		verbs: [
			"patch",
			"update",
		]
	}, {
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: ["create"]
	}]
}
objects: Role: "karpenter-dns": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter-dns"
		namespace: "kube-system"
	}
	rules: [{
		apiGroups: [""]
		resourceNames: ["kube-dns"]
		resources: ["services"]
		verbs: ["get"]
	}]
}
objects: ClusterRole: karpenter: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name: "karpenter"
	}
	rules: [{
		apiGroups: ["karpenter.k8s.aws"]
		resources: ["ec2nodeclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["karpenter.k8s.aws"]
		resources: [
			"ec2nodeclasses",
			"ec2nodeclasses/status",
		]
		verbs: [
			"patch",
			"update",
		]
	}]
}
objects: ClusterRole: "karpenter-admin": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":                   "karpenter"
			"app.kubernetes.io/managed-by":                 "Helm"
			"app.kubernetes.io/name":                       "karpenter"
			"app.kubernetes.io/version":                    "1.12.1"
			"helm.sh/chart":                                "karpenter-1.12.1"
			"rbac.authorization.k8s.io/aggregate-to-admin": "true"
		}
		name: "karpenter-admin"
	}
	rules: [{
		apiGroups: ["karpenter.sh"]
		resources: [
			"nodepools",
			"nodepools/status",
			"nodeclaims",
			"nodeclaims/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"delete",
			"patch",
		]
	}, {
		apiGroups: ["karpenter.k8s.aws"]
		resources: ["ec2nodeclasses"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"delete",
			"patch",
		]
	}]
}
objects: ClusterRole: "karpenter-core": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name: "karpenter-core"
	}
	rules: [{
		apiGroups: ["karpenter.sh"]
		resources: [
			"nodepools",
			"nodepools/status",
			"nodeclaims",
			"nodeclaims/status",
			"nodeoverlays",
			"nodeoverlays/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: [
			"pods",
			"nodes",
			"persistentvolumes",
			"persistentvolumeclaims",
			"replicationcontrollers",
			"namespaces",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: [
			"storageclasses",
			"csinodes",
			"volumeattachments",
		]
		verbs: [
			"get",
			"watch",
			"list",
		]
	}, {
		apiGroups: ["apps"]
		resources: [
			"daemonsets",
			"deployments",
			"replicasets",
			"statefulsets",
		]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["policy"]
		resources: ["poddisruptionbudgets"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["karpenter.sh"]
		resources: [
			"nodeclaims",
			"nodeclaims/status",
		]
		verbs: [
			"create",
			"delete",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["karpenter.sh"]
		resources: [
			"nodepools",
			"nodepools/status",
			"nodeoverlays/status",
		]
		verbs: [
			"update",
			"patch",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}, {
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"patch",
			"delete",
			"update",
		]
	}, {
		apiGroups: [""]
		resources: ["pods/eviction"]
		verbs: ["create"]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: ["delete"]
	}]
}
objects: RoleBinding: karpenter: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "karpenter"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "karpenter"
		namespace: "kube-system"
	}]
}
objects: RoleBinding: "karpenter-dns": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter-dns"
		namespace: "kube-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "karpenter-dns"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "karpenter"
		namespace: "kube-system"
	}]
}
objects: ClusterRoleBinding: karpenter: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name: "karpenter"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "karpenter"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "karpenter"
		namespace: "kube-system"
	}]
}
objects: ClusterRoleBinding: "karpenter-core": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name: "karpenter-core"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "karpenter-core"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "karpenter"
		namespace: "kube-system"
	}]
}
objects: Service: karpenter: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
	spec: {
		ports: [{
			name:       "http-metrics"
			port:       8080
			protocol:   "TCP"
			targetPort: "http-metrics"
		}]
		selector: {
			"app.kubernetes.io/instance": "karpenter"
			"app.kubernetes.io/name":     "karpenter"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: karpenter: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
	spec: {
		replicas:             2
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/instance": "karpenter"
			"app.kubernetes.io/name":     "karpenter"
		}
		strategy: rollingUpdate: maxUnavailable: 1
		template: {
			metadata: {
				annotations: null
				labels: {
					"app.kubernetes.io/instance": "karpenter"
					"app.kubernetes.io/name":     "karpenter"
				}
			}
			spec: {
				affinity: {
					nodeAffinity: requiredDuringSchedulingIgnoredDuringExecution: nodeSelectorTerms: [{
						matchExpressions: [{
							key:      "karpenter.sh/nodepool"
							operator: "DoesNotExist"
						}]
					}]
					podAntiAffinity: requiredDuringSchedulingIgnoredDuringExecution: [{
						labelSelector: matchLabels: {
							"app.kubernetes.io/instance": "karpenter"
							"app.kubernetes.io/name":     "karpenter"
						}
						topologyKey: "kubernetes.io/hostname"
					}]
				}
				automountServiceAccountToken: true
				containers: [{
					env: [{
						name:  "KUBERNETES_MIN_VERSION"
						value: "1.19.0-0"
					}, {
						name:  "KARPENTER_SERVICE"
						value: "karpenter"
					}, {
						name:  "LOG_LEVEL"
						value: "info"
					}, {
						name:  "LOG_OUTPUT_PATHS"
						value: "stdout"
					}, {
						name:  "LOG_ERROR_OUTPUT_PATHS"
						value: "stderr"
					}, {
						name:  "METRICS_PORT"
						value: "8080"
					}, {
						name:  "HEALTH_PROBE_PORT"
						value: "8081"
					}, {
						name: "SYSTEM_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name: "CPU_REQUESTS"
						valueFrom: resourceFieldRef: {
							containerName: "controller"
							divisor:       "1m"
							resource:      "requests.cpu"
						}
					}, {
						name: "MEMORY_LIMIT"
						valueFrom: resourceFieldRef: {
							containerName: "controller"
							divisor:       "0"
							resource:      "limits.memory"
						}
					}, {
						name:  "FEATURE_GATES"
						value: "ReservedCapacity=true,SpotToSpotConsolidation=false,NodeRepair=false,NodeOverlay=false,StaticCapacity=false"
					}, {
						name:  "BATCH_MAX_DURATION"
						value: "10s"
					}, {
						name:  "BATCH_IDLE_DURATION"
						value: "1s"
					}, {
						name:  "PREFERENCE_POLICY"
						value: "Respect"
					}, {
						name:  "MIN_VALUES_POLICY"
						value: "Strict"
					}, {
						name:  "CLUSTER_NAME"
						value: "placeholder"
					}, {
						name:  "VM_MEMORY_OVERHEAD_PERCENT"
						value: "0.075"
					}, {
						name:  "RESERVED_ENIS"
						value: "0"
					}, {
						name:  "IGNORE_DRA_REQUESTS"
						value: "true"
					}]
					image:           "host.k3d.internal:5000/mirror/public.ecr.aws/karpenter/controller:1.12.1"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 30
						timeoutSeconds:      30
					}
					name: "controller"
					ports: [{
						containerPort: 8080
						name:          "http-metrics"
						protocol:      "TCP"
					}, {
						containerPort: 8081
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						httpGet: {
							path: "/readyz"
							port: "http"
						}
						initialDelaySeconds: 5
						timeoutSeconds:      30
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						privileged:             false
						readOnlyRootFilesystem: true
						runAsGroup:             65532
						runAsNonRoot:           true
						runAsUser:              65532
					}
				}]
				dnsPolicy: "ClusterFirst"
				nodeSelector: "kubernetes.io/os": "linux"
				priorityClassName: "system-cluster-critical"
				schedulerName:     "default-scheduler"
				securityContext: {
					fsGroup: 65532
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "karpenter"
				tolerations: [{
					key:      "CriticalAddonsOnly"
					operator: "Exists"
				}]
				topologySpreadConstraints: [{
					labelSelector: matchLabels: {
						"app.kubernetes.io/instance": "karpenter"
						"app.kubernetes.io/name":     "karpenter"
					}
					maxSkew:           1
					topologyKey:       "topology.kubernetes.io/zone"
					whenUnsatisfiable: "DoNotSchedule"
				}]
			}
		}
	}
}
objects: PodDisruptionBudget: karpenter: {
	apiVersion: "policy/v1"
	kind:       "PodDisruptionBudget"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "karpenter"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "karpenter"
			"app.kubernetes.io/version":    "1.12.1"
			"helm.sh/chart":                "karpenter-1.12.1"
		}
		name:      "karpenter"
		namespace: "kube-system"
	}
	spec: {
		maxUnavailable: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "karpenter"
			"app.kubernetes.io/name":     "karpenter"
		}
	}
}
