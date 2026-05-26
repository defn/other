@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: StorageClass: "topolvm-provisioner": {
	allowVolumeExpansion: true
	apiVersion:           "storage.k8s.io/v1"
	kind:                 "StorageClass"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-provisioner"
	}
	parameters: "csi.storage.k8s.io/fstype": "xfs"
	provisioner:       "topolvm.io"
	volumeBindingMode: "WaitForFirstConsumer"
}
objects: ServiceAccount: "topolvm-controller": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}
}
objects: ServiceAccount: "topolvm-lvmd": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-lvmd"
		namespace: "topolvm-system"
	}
}
objects: ServiceAccount: "topolvm-node": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-node"
		namespace: "topolvm-system"
	}
}
objects: Role: "external-provisioner-cfg": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "external-provisioner-cfg"
		namespace: "topolvm-system"
	}
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"watch",
			"list",
			"delete",
			"update",
			"create",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["csistoragecapacities"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: ["get"]
	}, {
		apiGroups: ["apps"]
		resources: ["replicasets"]
		verbs: ["get"]
	}]
}
objects: Role: "external-resizer-cfg": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "external-resizer-cfg"
		namespace: "topolvm-system"
	}
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"watch",
			"list",
			"delete",
			"update",
			"create",
		]
	}]
}
objects: Role: "external-snapshotter-leaderelection": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "external-snapshotter-leaderelection"
		namespace: "topolvm-system"
	}
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"watch",
			"list",
			"delete",
			"update",
			"create",
		]
	}]
}
objects: Role: "leader-election": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "leader-election"
		namespace: "topolvm-system"
	}
	rules: [{
		apiGroups: [
			"",
			"coordination.k8s.io",
		]
		resources: [
			"configmaps",
			"leases",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}]
}
objects: ClusterRole: "topolvm-system-external-provisioner-runner": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-external-provisioner-runner"
	}
	rules: [{
		apiGroups: [""]
		resources: ["persistentvolumes"]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"patch",
			"delete",
		]
	}, {
		apiGroups: [""]
		resources: ["persistentvolumeclaims"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["storageclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"list",
			"watch",
			"create",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["snapshot.storage.k8s.io"]
		resources: ["volumesnapshots"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
		]
	}, {
		apiGroups: ["snapshot.storage.k8s.io"]
		resources: ["volumesnapshotcontents"]
		verbs: [
			"get",
			"list",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["csinodes"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["volumeattachments"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "topolvm-system-external-resizer-runner": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-external-resizer-runner"
	}
	rules: [{
		apiGroups: [""]
		resources: ["persistentvolumes"]
		verbs: [
			"get",
			"list",
			"watch",
			"patch",
		]
	}, {
		apiGroups: [""]
		resources: ["persistentvolumeclaims"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["persistentvolumeclaims/status"]
		verbs: ["patch"]
	}, {
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"list",
			"watch",
			"create",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["volumeattributesclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRole: "topolvm-system-external-snapshotter-runner": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-external-snapshotter-runner"
	}
	rules: [{
		apiGroups: [""]
		resources: ["events"]
		verbs: [
			"list",
			"watch",
			"create",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["snapshot.storage.k8s.io"]
		resources: ["volumesnapshotclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["snapshot.storage.k8s.io"]
		resources: ["volumesnapshotcontents"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["snapshot.storage.k8s.io"]
		resources: ["volumesnapshotcontents/status"]
		verbs: [
			"update",
			"patch",
		]
	}, {
		apiGroups: ["groupsnapshot.storage.k8s.io"]
		resources: ["volumegroupsnapshotclasses"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["groupsnapshot.storage.k8s.io"]
		resources: ["volumegroupsnapshotcontents"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["groupsnapshot.storage.k8s.io"]
		resources: ["volumegroupsnapshotcontents/status"]
		verbs: [
			"update",
			"patch",
		]
	}]
}
objects: ClusterRole: "topolvm-system:controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system:controller"
	}
	rules: [{
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"get",
			"list",
			"patch",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["persistentvolumeclaims"]
		verbs: [
			"delete",
			"get",
			"list",
			"update",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: [
			"get",
			"list",
			"update",
			"watch",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: [
			"csidrivers",
			"storageclasses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["topolvm.io"]
		resources: ["logicalvolumes"]
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
		apiGroups: ["topolvm.io"]
		resources: ["logicalvolumes/status"]
		verbs: [
			"get",
			"patch",
			"update",
		]
	}]
}
objects: ClusterRole: "topolvm-system:node": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system:node"
	}
	rules: [{
		apiGroups: [""]
		resources: ["nodes"]
		verbs: [
			"get",
			"list",
			"watch",
			"update",
			"patch",
		]
	}, {
		apiGroups: ["topolvm.io"]
		resources: [
			"logicalvolumes",
			"logicalvolumes/status",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"delete",
			"patch",
		]
	}, {
		apiGroups: ["storage.k8s.io"]
		resources: ["csidrivers"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: RoleBinding: "csi-provisioner-role-cfg": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "csi-provisioner-role-cfg"
		namespace: "topolvm-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "external-provisioner-cfg"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: RoleBinding: "csi-resizer-role-cfg": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "csi-resizer-role-cfg"
		namespace: "topolvm-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "external-resizer-cfg"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: RoleBinding: "external-snapshotter-leaderelection": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "external-snapshotter-leaderelection"
		namespace: "topolvm-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "external-snapshotter-leaderelection"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: RoleBinding: "leader-election": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "leader-election"
		namespace: "topolvm-system"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "leader-election"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: ClusterRoleBinding: "topolvm-system-csi-provisioner-role": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-csi-provisioner-role"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "topolvm-system-external-provisioner-runner"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: ClusterRoleBinding: "topolvm-system-csi-resizer-role": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-csi-resizer-role"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "topolvm-system-external-resizer-runner"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: ClusterRoleBinding: "topolvm-system-csi-snapshotter-role": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system-csi-snapshotter-role"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "topolvm-system-external-snapshotter-runner"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: ClusterRoleBinding: "topolvm-system:controller": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system:controller"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "topolvm-system:controller"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}]
}
objects: ClusterRoleBinding: "topolvm-system:node": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm-system:node"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "topolvm-system:node"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "topolvm-node"
		namespace: "topolvm-system"
	}]
}
objects: ConfigMap: "topolvm-lvmd-0": {
	apiVersion: "v1"
	data: "lvmd.yaml": """
		socket-name: /run/topolvm/lvmd.sock
		device-classes: 
		  - default: true
		    name: ssd
		    spare-gb: 10
		    volume-group: myvg1

		"""
	kind: "ConfigMap"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
			idx:                            "0"
		}
		name:      "topolvm-lvmd-0"
		namespace: "topolvm-system"
	}
}
objects: Service: "topolvm-controller": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}
	spec: {
		ports: [{
			name:       "webhook"
			port:       443
			protocol:   "TCP"
			targetPort: "webhook"
		}]
		selector: {
			"app.kubernetes.io/component": "controller"
			"app.kubernetes.io/instance":  "topolvm"
			"app.kubernetes.io/name":      "topolvm"
		}
	}
}
objects: PriorityClass: topolvm: {
	apiVersion:    "scheduling.k8s.io/v1"
	description:   "Pods using TopoLVM volumes should use this class."
	globalDefault: false
	kind:          "PriorityClass"
	metadata: name: "topolvm"
	value: 1000000
}
objects: Deployment: "topolvm-controller": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}
	spec: {
		replicas: 2
		selector: matchLabels: {
			"app.kubernetes.io/component": "controller"
			"app.kubernetes.io/instance":  "topolvm"
			"app.kubernetes.io/name":      "topolvm"
		}
		template: {
			metadata: labels: {
				"app.kubernetes.io/component": "controller"
				"app.kubernetes.io/instance":  "topolvm"
				"app.kubernetes.io/name":      "topolvm"
			}
			spec: {
				affinity: podAntiAffinity: requiredDuringSchedulingIgnoredDuringExecution: [{
					labelSelector: matchExpressions: [{
						key:      "app.kubernetes.io/component"
						operator: "In"
						values: ["controller"]
					}, {
						key:      "app.kubernetes.io/name"
						operator: "In"
						values: ["topolvm"]
					}]
					topologyKey: "kubernetes.io/hostname"
				}]
				containers: [{
					command: [
						"/topolvm-controller",
						"--leader-election-namespace=topolvm-system",
						"--enable-webhooks=false",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					livenessProbe: {
						httpGet: {
							path: "/healthz"
							port: "healthz"
						}
						initialDelaySeconds: 10
						periodSeconds:       60
						timeoutSeconds:      3
					}
					name: "topolvm-controller"
					ports: [{
						containerPort: 9443
						name:          "webhook"
						protocol:      "TCP"
					}, {
						containerPort: 9808
						name:          "healthz"
						protocol:      "TCP"
					}, {
						containerPort: 8081
						name:          "readyz"
						protocol:      "TCP"
					}, {
						containerPort: 8080
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: httpGet: {
						path:   "/readyz"
						port:   "readyz"
						scheme: "HTTP"
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{
						mountPath: "/run/topolvm"
						name:      "socket-dir"
					}]
				}, {
					command: [
						"/csi-provisioner",
						"--csi-address=/run/topolvm/csi-topolvm.sock",
						"--feature-gates=Topology=true",
						"--leader-election",
						"--leader-election-namespace=topolvm-system",
						"--http-endpoint=:9809",
						"--enable-capacity",
						"--capacity-ownerref-level=2",
					]
					env: [{
						name: "NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					name:  "csi-provisioner"
					ports: [{
						containerPort: 9809
						name:          "csi-provisioner"
					}]
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{
						mountPath: "/run/topolvm"
						name:      "socket-dir"
					}]
				}, {
					command: [
						"/csi-resizer",
						"--csi-address=/run/topolvm/csi-topolvm.sock",
						"--leader-election",
						"--leader-election-namespace=topolvm-system",
						"--http-endpoint=:9810",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					name:  "csi-resizer"
					ports: [{
						containerPort: 9810
						name:          "csi-resizer"
					}]
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{
						mountPath: "/run/topolvm"
						name:      "socket-dir"
					}]
				}, {
					command: [
						"/csi-snapshotter",
						"--csi-address=/run/topolvm/csi-topolvm.sock",
						"--leader-election",
						"--leader-election-namespace=topolvm-system",
						"--http-endpoint=:9811",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					name:  "csi-snapshotter"
					ports: [{
						containerPort: 9811
						name:          "csi-snapshotter"
					}]
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{
						mountPath: "/run/topolvm"
						name:      "socket-dir"
					}]
				}, {
					command: [
						"/livenessprobe",
						"--csi-address=/run/topolvm/csi-topolvm.sock",
						"--http-endpoint=:9808",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					name:  "liveness-probe"
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
					}
					volumeMounts: [{
						mountPath: "/run/topolvm"
						name:      "socket-dir"
					}]
				}]
				securityContext: {
					runAsGroup: 10000
					runAsUser:  10000
				}
				serviceAccountName: "topolvm-controller"
				volumes: [{
					emptyDir: {}
					name: "socket-dir"
				}]
			}
		}
	}
}
objects: PodDisruptionBudget: "topolvm-controller": {
	apiVersion: "policy/v1"
	kind:       "PodDisruptionBudget"
	metadata: {
		name:      "topolvm-controller"
		namespace: "topolvm-system"
	}
	spec: {
		maxUnavailable: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "controller"
			"app.kubernetes.io/instance":  "topolvm"
			"app.kubernetes.io/name":      "topolvm"
		}
	}
}
objects: DaemonSet: "topolvm-lvmd-0": {
	apiVersion: "apps/v1"
	kind:       "DaemonSet"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
			idx:                            "0"
		}
		name:      "topolvm-lvmd-0"
		namespace: "topolvm-system"
	}
	spec: {
		selector: matchLabels: {
			"app.kubernetes.io/component": "lvmd"
			"app.kubernetes.io/instance":  "topolvm"
			"app.kubernetes.io/name":      "topolvm"
			idx:                           "0"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":    "c388b92bc8d463974968502838ed6a04032e17980620657a68d05c4587af039c"
					"prometheus.io/port": "metrics"
				}
				labels: {
					"app.kubernetes.io/component": "lvmd"
					"app.kubernetes.io/instance":  "topolvm"
					"app.kubernetes.io/name":      "topolvm"
					idx:                           "0"
				}
			}
			spec: {
				containers: [{
					command: ["/lvmd"]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					livenessProbe: {
						exec: command: [
							"/lvmd",
							"health",
						]
						initialDelaySeconds: 10
						periodSeconds:       60
						timeoutSeconds:      3
					}
					name: "lvmd"
					ports: [{
						containerPort: 8080
						name:          "metrics"
						protocol:      "TCP"
					}]
					securityContext: privileged: true
					volumeMounts: [{
						mountPath: "/dev"
						name:      "devices-dir"
					}, {
						mountPath: "/etc/topolvm"
						name:      "config"
					}, {
						mountPath: "/run/topolvm"
						name:      "lvmd-socket-dir"
					}]
				}]
				hostPID:            true
				serviceAccountName: "topolvm-lvmd"
				volumes: [{
					hostPath: {
						path: "/dev"
						type: "Directory"
					}
					name: "devices-dir"
				}, {
					configMap: name: "topolvm-lvmd-0"
					name: "config"
				}, {
					hostPath: {
						path: "/run/topolvm"
						type: "DirectoryOrCreate"
					}
					name: "lvmd-socket-dir"
				}]
			}
		}
	}
}
objects: DaemonSet: "topolvm-node": {
	apiVersion: "apps/v1"
	kind:       "DaemonSet"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name:      "topolvm-node"
		namespace: "topolvm-system"
	}
	spec: {
		selector: matchLabels: {
			"app.kubernetes.io/component": "node"
			"app.kubernetes.io/instance":  "topolvm"
			"app.kubernetes.io/name":      "topolvm"
		}
		template: {
			metadata: {
				annotations: "prometheus.io/port": "metrics"
				labels: {
					"app.kubernetes.io/component": "node"
					"app.kubernetes.io/instance":  "topolvm"
					"app.kubernetes.io/name":      "topolvm"
				}
			}
			spec: {
				containers: [{
					command: [
						"/topolvm-node",
						"--csi-socket=/var/lib/kubelet/plugins/topolvm.io/node/csi-topolvm.sock",
						"--lvmd-socket=/run/topolvm/lvmd.sock",
					]
					env: [{
						name: "NODE_NAME"
						valueFrom: fieldRef: fieldPath: "spec.nodeName"
					}]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					livenessProbe: {
						httpGet: {
							path: "/healthz"
							port: "healthz"
						}
						initialDelaySeconds: 10
						periodSeconds:       60
						timeoutSeconds:      3
					}
					name: "topolvm-node"
					ports: [{
						containerPort: 9808
						name:          "healthz"
						protocol:      "TCP"
					}, {
						containerPort: 8080
						name:          "metrics"
						protocol:      "TCP"
					}]
					securityContext: privileged: true
					volumeMounts: [{
						mountPath: "/var/lib/kubelet/plugins/topolvm.io/node/"
						name:      "node-plugin-dir"
					}, {
						mountPath: "/run/topolvm"
						name:      "lvmd-socket-dir"
					}, {
						mountPath:        "/var/lib/kubelet/pods"
						mountPropagation: "Bidirectional"
						name:             "pod-volumes-dir"
					}, {
						mountPath:        "/var/lib/kubelet/plugins/kubernetes.io/csi"
						mountPropagation: "Bidirectional"
						name:             "csi-plugin-dir"
					}, {
						mountPath: "/dev"
						name:      "devices-dir"
					}]
				}, {
					command: [
						"/csi-node-driver-registrar",
						"--csi-address=/var/lib/kubelet/plugins/topolvm.io/node/csi-topolvm.sock",
						"--kubelet-registration-path=/var/lib/kubelet/plugins/topolvm.io/node/csi-topolvm.sock",
						"--http-endpoint=:9809",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					lifecycle: preStop: exec: command: [
						"/bin/sh",
						"-c",
						"rm -rf /registration/topolvm.io /registration/topolvm.io-reg.sock",
					]
					livenessProbe: {
						httpGet: {
							path: "/healthz"
							port: "reg-healthz"
						}
						initialDelaySeconds: 10
						periodSeconds:       60
						timeoutSeconds:      3
					}
					name: "csi-registrar"
					ports: [{
						containerPort: 9809
						name:          "reg-healthz"
					}]
					volumeMounts: [{
						mountPath: "/var/lib/kubelet/plugins/topolvm.io/node/"
						name:      "node-plugin-dir"
					}, {
						mountPath: "/registration"
						name:      "registration-dir"
					}]
				}, {
					command: [
						"/livenessprobe",
						"--csi-address=/var/lib/kubelet/plugins/topolvm.io/node/csi-topolvm.sock",
						"--http-endpoint=:9808",
					]
					image: "host.k3d.internal:5000/mirror/ghcr.io/topolvm/topolvm-with-sidecar:0.41.0"
					name:  "liveness-probe"
					volumeMounts: [{
						mountPath: "/var/lib/kubelet/plugins/topolvm.io/node/"
						name:      "node-plugin-dir"
					}]
				}]
				serviceAccountName: "topolvm-node"
				volumes: [{
					hostPath: {
						path: "/dev"
						type: "Directory"
					}
					name: "devices-dir"
				}, {
					hostPath: {
						path: "/var/lib/kubelet/plugins_registry/"
						type: "Directory"
					}
					name: "registration-dir"
				}, {
					hostPath: {
						path: "/var/lib/kubelet/plugins/topolvm.io/node"
						type: "DirectoryOrCreate"
					}
					name: "node-plugin-dir"
				}, {
					hostPath: {
						path: "/var/lib/kubelet/plugins/kubernetes.io/csi"
						type: "DirectoryOrCreate"
					}
					name: "csi-plugin-dir"
				}, {
					hostPath: {
						path: "/var/lib/kubelet/pods/"
						type: "DirectoryOrCreate"
					}
					name: "pod-volumes-dir"
				}, {
					hostPath: {
						path: "/run/topolvm"
						type: "Directory"
					}
					name: "lvmd-socket-dir"
				}]
			}
		}
	}
}
objects: CSIDriver: "topolvm.io": {
	apiVersion: "storage.k8s.io/v1"
	kind:       "CSIDriver"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "topolvm"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "topolvm"
			"app.kubernetes.io/version":    "0.41.0"
			"helm.sh/chart":                "topolvm-16.1.0"
		}
		name: "topolvm.io"
	}
	spec: {
		attachRequired:  false
		podInfoOnMount:  true
		storageCapacity: true
		volumeLifecycleModes: ["Persistent"]
	}
}
