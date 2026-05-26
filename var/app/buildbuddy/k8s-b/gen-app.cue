@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: Service: buildbuddy: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "buildbuddy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "buildbuddy"
			"helm.sh/chart":                "buildbuddy-0.0.409"
		}
		name: "buildbuddy"
	}
	spec: {
		ports: [{
			name:       "http"
			port:       80
			protocol:   "TCP"
			targetPort: 8080
		}, {
			appProtocol: "kubernetes.io/h2c"
			name:        "grpc"
			port:        1985
			protocol:    "TCP"
			targetPort:  1985
		}, {
			name:       "https"
			port:       443
			protocol:   "TCP"
			targetPort: 8081
		}, {
			appProtocol: "kubernetes.io/h2c"
			name:        "grpcs"
			port:        1986
			protocol:    "TCP"
			targetPort:  1986
		}]
		selector: {
			"app.kubernetes.io/instance": "buildbuddy"
			"app.kubernetes.io/name":     "buildbuddy"
		}
		type: "LoadBalancer"
	}
}
objects: PersistentVolumeClaim: buildbuddy: {
	apiVersion: "v1"
	kind:       "PersistentVolumeClaim"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "buildbuddy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "buildbuddy"
			"helm.sh/chart":                "buildbuddy-0.0.409"
		}
		name: "buildbuddy"
	}
	spec: {
		accessModes: ["ReadWriteOnce"]
		resources: requests: storage: "10Gi"
	}
}
objects: Deployment: buildbuddy: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "buildbuddy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "buildbuddy"
			"helm.sh/chart":                "buildbuddy-0.0.409"
		}
		name: "buildbuddy"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/instance": "buildbuddy"
			"app.kubernetes.io/name":     "buildbuddy"
		}
		strategy: type: "RollingUpdate"
		template: {
			metadata: {
				annotations: "checksum/config": "ed2867b734b239a246105d191be4135e7186fec948010e35be21beee4b3c828b"
				labels: {
					"app.kubernetes.io/instance":   "buildbuddy"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "buildbuddy"
					"helm.sh/chart":                "buildbuddy-0.0.409"
				}
			}
			spec: {
				containers: [{
					env:             null
					image:           "host.k3d.internal:5000/mirror/buildbuddy.bbcr.io/public/buildbuddy-app-onprem:v2.269.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						failureThreshold: 3
						httpGet: {
							httpHeaders: [{
								name:  "server-type"
								value: "buildbuddy-server"
							}]
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 10
						timeoutSeconds:      5
					}
					name: "buildbuddy"
					ports: [{
						containerPort: 8080
						name:          "http"
					}, {
						containerPort: 1985
						name:          "grpc"
					}, {
						containerPort: 8081
						name:          "https"
					}, {
						containerPort: 1986
						name:          "grpcs"
					}]
					readinessProbe: httpGet: {
						httpHeaders: [{
							name:  "server-type"
							value: "buildbuddy-server"
						}]
						path: "/readyz"
						port: "http"
					}
					volumeMounts: [{
						mountPath: "/data"
						name:      "data"
					}, {
						mountPath: "/config.yaml"
						name:      "config"
						subPath:   "config.yaml"
					}]
				}]
				initContainers: []
				volumes: [{
					name: "config"
					secret: secretName: "buildbuddy-config"
				}, {
					name: "data"
					persistentVolumeClaim: claimName: "buildbuddy"
				}]
			}
		}
	}
}
