@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "trust-manager": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "trust-manager"
	}
}
objects: Role: "trust-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "cert-manager"
	}
	rules: [{
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: Role: "trust-manager:leaderelection": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager:leaderelection"
		namespace: "trust-manager"
	}
	rules: [{
		apiGroups: ["coordination.k8s.io"]
		resources: ["leases"]
		verbs: [
			"get",
			"create",
			"update",
			"watch",
			"list",
		]
	}]
}
objects: ClusterRole: "trust-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name: "trust-manager"
	}
	rules: [{
		apiGroups: ["trust.cert-manager.io"]
		resources: ["bundles"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["trust.cert-manager.io"]
		resources: ["bundles/finalizers"]
		verbs: ["update"]
	}, {
		apiGroups: ["trust.cert-manager.io"]
		resources: ["bundles/status"]
		verbs: ["patch"]
	}, {
		apiGroups: [""]
		resources: ["namespaces"]
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
			"create",
			"patch",
			"watch",
			"delete",
		]
	}, {
		apiGroups: [
			"",
			"events.k8s.io",
		]
		resources: ["events"]
		verbs: [
			"create",
			"patch",
		]
	}]
}
objects: RoleBinding: "trust-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "cert-manager"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "trust-manager"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "trust-manager"
		namespace: "trust-manager"
	}]
}
objects: RoleBinding: "trust-manager:leaderelection": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager:leaderelection"
		namespace: "trust-manager"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "trust-manager:leaderelection"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "trust-manager"
		namespace: "trust-manager"
	}]
}
objects: ClusterRoleBinding: "trust-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name: "trust-manager"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "trust-manager"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "trust-manager"
		namespace: "trust-manager"
	}]
}
objects: Service: "trust-manager": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			app:                            "trust-manager"
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "trust-manager"
	}
	spec: {
		ports: [{
			name:       "webhook"
			port:       443
			protocol:   "TCP"
			targetPort: 6443
		}]
		selector: app: "trust-manager"
		type: "ClusterIP"
	}
}
objects: Service: "trust-manager-metrics": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			app:                            "trust-manager"
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager-metrics"
		namespace: "trust-manager"
	}
	spec: {
		ports: [{
			name:       "metrics"
			port:       9402
			protocol:   "TCP"
			targetPort: 9402
		}]
		selector: app: "trust-manager"
		type: "ClusterIP"
	}
}
objects: Deployment: "trust-manager": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "trust-manager"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: app: "trust-manager"
		template: {
			metadata: labels: {
				app:                            "trust-manager"
				"app.kubernetes.io/instance":   "trust-manager"
				"app.kubernetes.io/managed-by": "Helm"
				"app.kubernetes.io/name":       "trust-manager"
				"app.kubernetes.io/version":    "v0.22.1"
				"helm.sh/chart":                "trust-manager-v0.22.1"
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--log-format=text",
						"--log-level=1",
						"--metrics-port=9402",
						"--readiness-probe-port=6060",
						"--readiness-probe-path=/readyz",
						"--leader-elect=true",
						"--leader-election-lease-duration=15s",
						"--leader-election-renew-deadline=10s",
						"--trust-namespace=cert-manager",
						"--webhook-host=0.0.0.0",
						"--webhook-port=6443",
						"--webhook-certificate-dir=/tls",
						"--default-package-location=/packages/cert-manager-package-debian.json",
					]
					image:           "host.k3d.internal:5000/mirror/quay.io/jetstack/trust-manager:v0.22.1"
					imagePullPolicy: "IfNotPresent"
					name:            "trust-manager"
					ports: [{
						containerPort: 6443
						name:          "webhook"
					}, {
						containerPort: 9402
						name:          "metrics"
					}]
					readinessProbe: {
						httpGet: {
							path: "/readyz"
							port: 6060
						}
						initialDelaySeconds: 3
						periodSeconds:       7
					}
					resources: {}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/tls"
						name:      "tls"
						readOnly:  true
					}, {
						mountPath: "/packages"
						name:      "packages"
						readOnly:  true
					}]
				}]
				initContainers: [{
					args: [
						"/copyandmaybepause",
						"/debian-package",
						"/packages",
					]
					image:           "host.k3d.internal:5000/mirror/quay.io/jetstack/trust-pkg-debian-bookworm:20230311-deb12u1.5"
					imagePullPolicy: "IfNotPresent"
					name:            "cert-manager-package-debian"
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsNonRoot:           true
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/packages"
						name:      "packages"
						readOnly:  false
					}]
				}]
				nodeSelector: "kubernetes.io/os": "linux"
				serviceAccountName: "trust-manager"
				volumes: [{
					emptyDir: sizeLimit: "50M"
					name: "packages"
				}, {
					name: "tls"
					secret: {
						defaultMode: 420
						secretName:  "trust-manager-tls"
					}
				}]
			}
		}
	}
}
objects: Certificate: "trust-manager": {
	apiVersion: "cert-manager.io/v1"
	kind:       "Certificate"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "trust-manager"
	}
	spec: {
		commonName: "trust-manager.trust-manager.svc"
		dnsNames: ["trust-manager.trust-manager.svc"]
		issuerRef: {
			group: "cert-manager.io"
			kind:  "Issuer"
			name:  "trust-manager"
		}
		privateKey: rotationPolicy: "Always"
		revisionHistoryLimit: 1
		secretName:           "trust-manager-tls"
	}
}
objects: Issuer: "trust-manager": {
	apiVersion: "cert-manager.io/v1"
	kind:       "Issuer"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name:      "trust-manager"
		namespace: "trust-manager"
	}
	spec: selfSigned: {}
}
objects: ValidatingWebhookConfiguration: "trust-manager": {
	apiVersion: "admissionregistration.k8s.io/v1"
	kind:       "ValidatingWebhookConfiguration"
	metadata: {
		annotations: "cert-manager.io/inject-ca-from": "trust-manager/trust-manager"
		labels: {
			app:                            "trust-manager"
			"app.kubernetes.io/instance":   "trust-manager"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "trust-manager"
			"app.kubernetes.io/version":    "v0.22.1"
			"helm.sh/chart":                "trust-manager-v0.22.1"
		}
		name: "trust-manager"
	}
	webhooks: [{
		admissionReviewVersions: ["v1"]
		clientConfig: service: {
			name:      "trust-manager"
			namespace: "trust-manager"
			path:      "/validate-trust-cert-manager-io-v1alpha1-bundle"
		}
		failurePolicy: "Fail"
		name:          "trust.cert-manager.io"
		rules: [{
			apiGroups: ["trust.cert-manager.io"]
			apiVersions: ["v1alpha1"]
			operations: [
				"CREATE",
				"UPDATE",
			]
			resources: ["bundles"]
		}]
		sideEffects:    "None"
		timeoutSeconds: 5
	}]
}
