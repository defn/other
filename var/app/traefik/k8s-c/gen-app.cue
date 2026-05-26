@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: traefik: {
	apiVersion:                   "v1"
	automountServiceAccountToken: false
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name:      "traefik"
		namespace: "traefik"
	}
}
objects: ClusterRole: "traefik-traefik": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name: "traefik-traefik"
	}
	rules: [{
		apiGroups: [""]
		resources: [
			"configmaps",
			"nodes",
			"services",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: ["discovery.k8s.io"]
		resources: ["endpointslices"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: [""]
		resources: ["pods"]
		verbs: ["get"]
	}, {
		apiGroups: [""]
		resources: ["secrets"]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		]
		resources: [
			"ingressclasses",
			"ingresses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		]
		resources: ["ingresses/status"]
		verbs: ["update"]
	}, {
		apiGroups: [""]
		resources: ["namespaces"]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: ["traefik.io"]
		resources: [
			"ingressroutes",
			"ingressroutetcps",
			"ingressrouteudps",
			"middlewares",
			"middlewaretcps",
			"serverstransports",
			"serverstransporttcps",
			"tlsoptions",
			"tlsstores",
			"traefikservices",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}
objects: ClusterRoleBinding: "traefik-traefik": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name: "traefik-traefik"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "traefik-traefik"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "traefik"
		namespace: "traefik"
	}]
}
objects: Service: traefik: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name:      "traefik"
		namespace: "traefik"
	}
	spec: {
		ports: [{
			name:       "web"
			port:       80
			protocol:   "TCP"
			targetPort: "web"
		}, {
			name:       "websecure"
			port:       443
			protocol:   "TCP"
			targetPort: "websecure"
		}]
		selector: {
			"app.kubernetes.io/instance": "traefik-traefik"
			"app.kubernetes.io/name":     "traefik"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: traefik: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name:      "traefik"
		namespace: "traefik"
	}
	spec: {
		minReadySeconds: 0
		replicas:        1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "traefik-traefik"
			"app.kubernetes.io/name":     "traefik"
		}
		strategy: {
			rollingUpdate: {
				maxSurge:       1
				maxUnavailable: 0
			}
			type: "RollingUpdate"
		}
		template: {
			metadata: {
				annotations: {
					"prometheus.io/path":   "/metrics"
					"prometheus.io/port":   "9100"
					"prometheus.io/scrape": "true"
				}
				labels: {
					"app.kubernetes.io/instance":   "traefik-traefik"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "traefik"
					"helm.sh/chart":                "traefik-40.2.0"
				}
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--entryPoints.metrics.address=:9100/tcp",
						"--entryPoints.traefik.address=:8080/tcp",
						"--entryPoints.web.address=:8000/tcp",
						"--entryPoints.websecure.address=:8443/tcp",
						"--api.dashboard=true",
						"--ping=true",
						"--metrics.prometheus=true",
						"--metrics.prometheus.entrypoint=metrics",
						"--providers.kubernetescrd",
						"--providers.kubernetescrd.allowCrossNamespace=true",
						"--providers.kubernetescrd.allowEmptyServices=true",
						"--providers.kubernetesingress",
						"--providers.kubernetesingress.allowEmptyServices=true",
						"--providers.kubernetesingress.ingressendpoint.publishedservice=traefik/traefik",
						"--entryPoints.websecure.http.tls=true",
						"--log.level=INFO",
					]
					env: [{
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "USER"
						value: "traefik"
					}]
					image:           "host.k3d.internal:5000/mirror/docker.io/traefik:v3.7.1"
					imagePullPolicy: "IfNotPresent"
					lifecycle:       null
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							path:   "/ping"
							port:   8080
							scheme: "HTTP"
						}
						initialDelaySeconds: 2
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      2
					}
					name: "traefik"
					ports: [{
						containerPort: 9100
						name:          "metrics"
						protocol:      "TCP"
					}, {
						containerPort: 8080
						name:          "traefik"
						protocol:      "TCP"
					}, {
						containerPort: 8000
						name:          "web"
						protocol:      "TCP"
					}, {
						containerPort: 8443
						name:          "websecure"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 1
						httpGet: {
							path:   "/ping"
							port:   8080
							scheme: "HTTP"
						}
						initialDelaySeconds: 2
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      2
					}
					resources: null
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
					volumeMounts: [{
						mountPath: "/data"
						name:      "data"
					}, {
						mountPath: "/tmp"
						name:      "tmp"
					}]
				}]
				hostNetwork: false
				securityContext: {
					runAsGroup:   65532
					runAsNonRoot: true
					runAsUser:    65532
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName:            "traefik"
				terminationGracePeriodSeconds: 60
				volumes: [{
					emptyDir: {}
					name: "data"
				}, {
					emptyDir: {}
					name: "tmp"
				}]
			}
		}
	}
}
objects: IngressClass: traefik: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "IngressClass"
	metadata: {
		annotations: "ingressclass.kubernetes.io/is-default-class": "true"
		labels: {
			"app.kubernetes.io/instance":   "traefik-traefik"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "traefik"
			"helm.sh/chart":                "traefik-40.2.0"
		}
		name: "traefik"
	}
	spec: controller: "traefik.io/ingress-controller"
}
