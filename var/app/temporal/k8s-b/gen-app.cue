@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ConfigMap: "temporal-config": {
	apiVersion: "v1"
	data: "config_template.yaml": """
		# enable-template
		log:
		  stdout: true
		  level: "debug,info"

		persistence:
		  datastores:
		    default:
		      sql:
		        connectAddr: temporal-db-rw.temporal.svc:5432
		        connectProtocol: tcp
		        databaseName: temporal
		        driverName: postgres12_pgx
		        maxConnLifetime: 1h
		        maxConns: 20
		        maxIdleConns: 20
		        password: {{ env "TEMPORAL_DEFAULT_STORE_PASSWORD" | quote }}
		        pluginName: postgres12_pgx
		        user: temporal
		    visibility:
		      sql:
		        connectAddr: temporal-db-rw.temporal.svc:5432
		        connectProtocol: tcp
		        databaseName: temporal_visibility
		        driverName: postgres12_pgx
		        maxConnLifetime: 1h
		        maxConns: 20
		        maxIdleConns: 20
		        password: {{ env "TEMPORAL_VISIBILITY_STORE_PASSWORD" | quote }}
		        pluginName: postgres12_pgx
		        user: temporal
		  defaultStore: default
		  numHistoryShards: 512
		  visibilityStore: visibility

		global:
		  membership:
		    name: temporal
		    maxJoinDuration: 30s
		    broadcastAddress: {{ env "POD_IP" | quote }}

		  pprof:
		    port: 7936

		  metrics:
		    tags:
		      type: {{ env "TEMPORAL_SERVICES" | quote }}
		    prometheus:
		      listenAddress: 0.0.0.0:9090
		      timerType: histogram

		services:
		  frontend:
		    rpc:
		      grpcPort: 7233
		      httpPort: 7243
		      membershipPort: 6933
		      bindOnIP: "0.0.0.0"

		  history:
		    rpc:
		      grpcPort: 7234
		      membershipPort: 6934
		      bindOnIP: "0.0.0.0"

		  matching:
		    rpc:
		      grpcPort: 7235
		      membershipPort: 6935
		      bindOnIP: "0.0.0.0"

		  worker:
		    rpc:
		      membershipPort: 6939
		      bindOnIP: "0.0.0.0"

		clusterMetadata:
		  enableGlobalNamespace: false
		  failoverVersionIncrement: 10
		  masterClusterName: "active"
		  currentClusterName: "active"
		  clusterInformation:
		    active:
		      enabled: true
		      initialFailoverVersion: 1
		      rpcName: "temporal-frontend"
		      rpcAddress: "127.0.0.1:7233"
		      httpAddress: "127.0.0.1:7243"

		dcRedirectionPolicy:
		  policy: "noop"
		  toDC: ""

		archival:
		  status: "disabled"
		publicClient:
		  hostPort: "temporal-frontend:7233"

		dynamicConfigClient:
		  filepath: "/etc/temporal/dynamic_config/dynamic_config.yaml"
		  pollInterval: "10s"
		"""
	kind: "ConfigMap"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-config"
	}
}
objects: ConfigMap: "temporal-dynamic-config": {
	apiVersion: "v1"
	data: "dynamic_config.yaml": ""
	kind: "ConfigMap"
	metadata: {
		labels: {
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-dynamic-config"
	}
}
objects: Service: "temporal-frontend": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "frontend"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-frontend"
	}
	spec: {
		ports: [{
			appProtocol: "tcp"
			name:        "grpc-rpc"
			port:        7233
			protocol:    "TCP"
			targetPort:  "rpc"
		}, {
			appProtocol: "http"
			name:        "http"
			port:        7243
			protocol:    "TCP"
			targetPort:  "http"
		}]
		selector: {
			"app.kubernetes.io/component": "frontend"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Service: "temporal-frontend-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: {
			"prometheus.io/job":                                      "temporal-frontend"
			"prometheus.io/port":                                     "9090"
			"prometheus.io/scheme":                                   "http"
			"prometheus.io/scrape":                                   "true"
			"service.alpha.kubernetes.io/tolerate-unready-endpoints": "true"
		}
		labels: {
			"app.kubernetes.io/component":  "frontend"
			"app.kubernetes.io/headless":   "true"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-frontend-headless"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			appProtocol: "tcp"
			name:        "grpc-rpc"
			port:        7233
			protocol:    "TCP"
			targetPort:  "rpc"
		}, {
			appProtocol: "tcp"
			name:        "grpc-membership"
			port:        6933
			protocol:    "TCP"
			targetPort:  "membership"
		}, {
			appProtocol: "http"
			name:        "metrics"
			port:        9090
			protocol:    "TCP"
			targetPort:  "metrics"
		}]
		publishNotReadyAddresses: true
		selector: {
			"app.kubernetes.io/component": "frontend"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Service: "temporal-history-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: {
			"prometheus.io/job":                                      "temporal-history"
			"prometheus.io/port":                                     "9090"
			"prometheus.io/scheme":                                   "http"
			"prometheus.io/scrape":                                   "true"
			"service.alpha.kubernetes.io/tolerate-unready-endpoints": "true"
		}
		labels: {
			"app.kubernetes.io/component":  "history"
			"app.kubernetes.io/headless":   "true"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-history-headless"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			appProtocol: "tcp"
			name:        "grpc-rpc"
			port:        7234
			protocol:    "TCP"
			targetPort:  "rpc"
		}, {
			appProtocol: "tcp"
			name:        "grpc-membership"
			port:        6934
			protocol:    "TCP"
			targetPort:  "membership"
		}, {
			appProtocol: "http"
			name:        "metrics"
			port:        9090
			protocol:    "TCP"
			targetPort:  "metrics"
		}]
		publishNotReadyAddresses: true
		selector: {
			"app.kubernetes.io/component": "history"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Service: "temporal-matching-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: {
			"prometheus.io/job":                                      "temporal-matching"
			"prometheus.io/port":                                     "9090"
			"prometheus.io/scheme":                                   "http"
			"prometheus.io/scrape":                                   "true"
			"service.alpha.kubernetes.io/tolerate-unready-endpoints": "true"
		}
		labels: {
			"app.kubernetes.io/component":  "matching"
			"app.kubernetes.io/headless":   "true"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-matching-headless"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			appProtocol: "tcp"
			name:        "grpc-rpc"
			port:        7235
			protocol:    "TCP"
			targetPort:  "rpc"
		}, {
			appProtocol: "tcp"
			name:        "grpc-membership"
			port:        6935
			protocol:    "TCP"
			targetPort:  "membership"
		}, {
			appProtocol: "http"
			name:        "metrics"
			port:        9090
			protocol:    "TCP"
			targetPort:  "metrics"
		}]
		publishNotReadyAddresses: true
		selector: {
			"app.kubernetes.io/component": "matching"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Service: "temporal-web": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "web"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-web"
	}
	spec: {
		ports: [{
			appProtocol: "http"
			name:        "http"
			port:        8080
			protocol:    "TCP"
			targetPort:  "http"
		}]
		selector: {
			"app.kubernetes.io/component": "web"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Service: "temporal-worker-headless": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		annotations: {
			"prometheus.io/job":                                      "temporal-worker"
			"prometheus.io/port":                                     "9090"
			"prometheus.io/scheme":                                   "http"
			"prometheus.io/scrape":                                   "true"
			"service.alpha.kubernetes.io/tolerate-unready-endpoints": "true"
		}
		labels: {
			"app.kubernetes.io/component":  "worker"
			"app.kubernetes.io/headless":   "true"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-worker-headless"
	}
	spec: {
		clusterIP: "None"
		ports: [{
			appProtocol: "tcp"
			name:        "grpc-rpc"
			port:        7239
			protocol:    "TCP"
			targetPort:  "rpc"
		}, {
			appProtocol: "tcp"
			name:        "grpc-membership"
			port:        6939
			protocol:    "TCP"
			targetPort:  "membership"
		}, {
			appProtocol: "http"
			name:        "metrics"
			port:        9090
			protocol:    "TCP"
			targetPort:  "metrics"
		}]
		publishNotReadyAddresses: true
		selector: {
			"app.kubernetes.io/component": "worker"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: "temporal-admintools": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "admintools"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-admintools"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "admintools"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: null
				labels: {
					"app.kubernetes.io/component":  "admintools"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name:  "TEMPORAL_CLI_ADDRESS"
						value: "temporal-frontend:7233"
					}, {
						name:  "TEMPORAL_ADDRESS"
						value: "temporal-frontend:7233"
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						exec: command: [
							"ls",
							"/",
						]
						initialDelaySeconds: 5
						periodSeconds:       5
					}
					name: "admin-tools"
				}]
				serviceAccountName: "default"
			}
		}
	}
}
objects: Deployment: "temporal-frontend": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "frontend"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-frontend"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "frontend"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":      "1c48009cbb3e9351fb92274d45d9a2289da54275123a3ba7e7393a6c6b120a23"
					"prometheus.io/job":    "temporal-frontend"
					"prometheus.io/port":   "9090"
					"prometheus.io/scheme": "http"
					"prometheus.io/scrape": "true"
				}
				labels: {
					"app.kubernetes.io/component":  "frontend"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "POD_IP"
						valueFrom: fieldRef: fieldPath: "status.podIP"
					}, {
						name:  "SERVICES"
						value: "frontend"
					}, {
						name:  "TEMPORAL_SERVICES"
						value: "frontend"
					}, {
						name:  "TEMPORAL_SERVER_CONFIG_FILE_PATH"
						value: "/etc/temporal/config/config_template.yaml"
					}, {
						name: "TEMPORAL_DEFAULT_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}, {
						name: "TEMPORAL_VISIBILITY_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/server:1.31.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						initialDelaySeconds: 150
						tcpSocket: port: "rpc"
					}
					name: "temporal-frontend"
					ports: [{
						containerPort: 7233
						name:          "rpc"
						protocol:      "TCP"
					}, {
						containerPort: 6933
						name:          "membership"
						protocol:      "TCP"
					}, {
						containerPort: 7243
						name:          "http"
						protocol:      "TCP"
					}, {
						containerPort: 9090
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: grpc: {
						port:    7233
						service: "temporal.api.workflowservice.v1.WorkflowService"
					}
					resources: {}
					volumeMounts: [{
						mountPath: "/etc/temporal/config/config_template.yaml"
						name:      "config"
						subPath:   "config_template.yaml"
					}, {
						mountPath: "/etc/temporal/dynamic_config"
						name:      "dynamic-config"
					}]
				}]
				securityContext: {
					fsGroup:   1000
					runAsUser: 1000
				}
				serviceAccountName:            "default"
				terminationGracePeriodSeconds: null
				volumes: [{
					configMap: name: "temporal-config"
					name: "config"
				}, {
					configMap: {
						items: [{
							key:  "dynamic_config.yaml"
							path: "dynamic_config.yaml"
						}]
						name: "temporal-dynamic-config"
					}
					name: "dynamic-config"
				}]
			}
		}
	}
}
objects: Deployment: "temporal-history": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "history"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-history"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "history"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":      "1c48009cbb3e9351fb92274d45d9a2289da54275123a3ba7e7393a6c6b120a23"
					"prometheus.io/job":    "temporal-history"
					"prometheus.io/port":   "9090"
					"prometheus.io/scheme": "http"
					"prometheus.io/scrape": "true"
				}
				labels: {
					"app.kubernetes.io/component":  "history"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "POD_IP"
						valueFrom: fieldRef: fieldPath: "status.podIP"
					}, {
						name:  "SERVICES"
						value: "history"
					}, {
						name:  "TEMPORAL_SERVICES"
						value: "history"
					}, {
						name:  "TEMPORAL_SERVER_CONFIG_FILE_PATH"
						value: "/etc/temporal/config/config_template.yaml"
					}, {
						name: "TEMPORAL_DEFAULT_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}, {
						name: "TEMPORAL_VISIBILITY_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/server:1.31.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						initialDelaySeconds: 150
						tcpSocket: port: "rpc"
					}
					name: "temporal-history"
					ports: [{
						containerPort: 7234
						name:          "rpc"
						protocol:      "TCP"
					}, {
						containerPort: 6934
						name:          "membership"
						protocol:      "TCP"
					}, {
						containerPort: 9090
						name:          "metrics"
						protocol:      "TCP"
					}]
					resources: {}
					volumeMounts: [{
						mountPath: "/etc/temporal/config/config_template.yaml"
						name:      "config"
						subPath:   "config_template.yaml"
					}, {
						mountPath: "/etc/temporal/dynamic_config"
						name:      "dynamic-config"
					}]
				}]
				securityContext: {
					fsGroup:   1000
					runAsUser: 1000
				}
				serviceAccountName:            "default"
				terminationGracePeriodSeconds: null
				volumes: [{
					configMap: name: "temporal-config"
					name: "config"
				}, {
					configMap: {
						items: [{
							key:  "dynamic_config.yaml"
							path: "dynamic_config.yaml"
						}]
						name: "temporal-dynamic-config"
					}
					name: "dynamic-config"
				}]
			}
		}
	}
}
objects: Deployment: "temporal-matching": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "matching"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-matching"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "matching"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":      "1c48009cbb3e9351fb92274d45d9a2289da54275123a3ba7e7393a6c6b120a23"
					"prometheus.io/job":    "temporal-matching"
					"prometheus.io/port":   "9090"
					"prometheus.io/scheme": "http"
					"prometheus.io/scrape": "true"
				}
				labels: {
					"app.kubernetes.io/component":  "matching"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "POD_IP"
						valueFrom: fieldRef: fieldPath: "status.podIP"
					}, {
						name:  "SERVICES"
						value: "matching"
					}, {
						name:  "TEMPORAL_SERVICES"
						value: "matching"
					}, {
						name:  "TEMPORAL_SERVER_CONFIG_FILE_PATH"
						value: "/etc/temporal/config/config_template.yaml"
					}, {
						name: "TEMPORAL_DEFAULT_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}, {
						name: "TEMPORAL_VISIBILITY_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/server:1.31.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						initialDelaySeconds: 150
						tcpSocket: port: "rpc"
					}
					name: "temporal-matching"
					ports: [{
						containerPort: 7235
						name:          "rpc"
						protocol:      "TCP"
					}, {
						containerPort: 6935
						name:          "membership"
						protocol:      "TCP"
					}, {
						containerPort: 9090
						name:          "metrics"
						protocol:      "TCP"
					}]
					resources: {}
					volumeMounts: [{
						mountPath: "/etc/temporal/config/config_template.yaml"
						name:      "config"
						subPath:   "config_template.yaml"
					}, {
						mountPath: "/etc/temporal/dynamic_config"
						name:      "dynamic-config"
					}]
				}]
				securityContext: {
					fsGroup:   1000
					runAsUser: 1000
				}
				serviceAccountName:            "default"
				terminationGracePeriodSeconds: null
				volumes: [{
					configMap: name: "temporal-config"
					name: "config"
				}, {
					configMap: {
						items: [{
							key:  "dynamic_config.yaml"
							path: "dynamic_config.yaml"
						}]
						name: "temporal-dynamic-config"
					}
					name: "dynamic-config"
				}]
			}
		}
	}
}
objects: Deployment: "temporal-web": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "web"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-web"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "web"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: null
				labels: {
					"app.kubernetes.io/component":  "web"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name:  "TEMPORAL_ADDRESS"
						value: "temporal-frontend.temporal.svc:7233"
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/ui:2.49.1"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						initialDelaySeconds: 10
						tcpSocket: port: "http"
					}
					name: "temporal-web"
					ports: [{
						containerPort: 8080
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 10
					}
					resources: {}
				}]
				serviceAccountName: "default"
			}
		}
	}
}
objects: Deployment: "temporal-worker": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "worker"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-worker"
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/component": "worker"
			"app.kubernetes.io/instance":  "temporal"
			"app.kubernetes.io/name":      "temporal"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":      "1c48009cbb3e9351fb92274d45d9a2289da54275123a3ba7e7393a6c6b120a23"
					"prometheus.io/job":    "temporal-worker"
					"prometheus.io/port":   "9090"
					"prometheus.io/scheme": "http"
					"prometheus.io/scrape": "true"
				}
				labels: {
					"app.kubernetes.io/component":  "worker"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
			}
			spec: {
				containers: [{
					env: [{
						name: "POD_IP"
						valueFrom: fieldRef: fieldPath: "status.podIP"
					}, {
						name:  "SERVICES"
						value: "worker"
					}, {
						name:  "TEMPORAL_SERVICES"
						value: "worker"
					}, {
						name:  "TEMPORAL_SERVER_CONFIG_FILE_PATH"
						value: "/etc/temporal/config/config_template.yaml"
					}, {
						name: "TEMPORAL_DEFAULT_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}, {
						name: "TEMPORAL_VISIBILITY_STORE_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/server:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "temporal-worker"
					ports: [{
						containerPort: 6939
						name:          "membership"
						protocol:      "TCP"
					}, {
						containerPort: 9090
						name:          "metrics"
						protocol:      "TCP"
					}]
					resources: {}
					volumeMounts: [{
						mountPath: "/etc/temporal/config/config_template.yaml"
						name:      "config"
						subPath:   "config_template.yaml"
					}, {
						mountPath: "/etc/temporal/dynamic_config"
						name:      "dynamic-config"
					}]
				}]
				securityContext: {
					fsGroup:   1000
					runAsUser: 1000
				}
				serviceAccountName:            "default"
				terminationGracePeriodSeconds: null
				volumes: [{
					configMap: name: "temporal-config"
					name: "config"
				}, {
					configMap: {
						items: [{
							key:  "dynamic_config.yaml"
							path: "dynamic_config.yaml"
						}]
						name: "temporal-dynamic-config"
					}
					name: "dynamic-config"
				}]
			}
		}
	}
}
objects: Job: "temporal-namespace-1-2-0-1": {
	apiVersion: "batch/v1"
	kind:       "Job"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "database"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-namespace-1-2-0-1"
	}
	spec: {
		backoffLimit: 100
		template: {
			metadata: {
				labels: {
					"app.kubernetes.io/component":  "database"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
				name: "temporal-namespace-1-2-0-1"
			}
			spec: {
				containers: [{
					command: [
						"sh",
						"-c",
						"echo \"Namespace setup completed\"",
					]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "done"
				}]
				initContainers: [{
					args: ["temporal operator namespace describe -n default || temporal operator namespace create -n default --retention 3d"]
					command: [
						"/bin/sh",
						"-c",
					]
					env: [{
						name:  "TEMPORAL_ADDRESS"
						value: "temporal-frontend.temporal.svc:7233"
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "create-default-namespace"
				}]
				restartPolicy:      "OnFailure"
				serviceAccountName: "default"
			}
		}
		ttlSecondsAfterFinished: 86400
	}
}
objects: Job: "temporal-schema-1-2-0-1": {
	apiVersion: "batch/v1"
	kind:       "Job"
	metadata: {
		labels: {
			"app.kubernetes.io/component":  "database"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-schema-1-2-0-1"
	}
	spec: {
		backoffLimit: 100
		template: {
			metadata: {
				labels: {
					"app.kubernetes.io/component":  "database"
					"app.kubernetes.io/instance":   "temporal"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "temporal"
					"app.kubernetes.io/part-of":    "temporal"
					"app.kubernetes.io/version":    "1.31.0"
					"helm.sh/chart":                "temporal-1.2.0"
				}
				name: "temporal-schema-1-2-0-1"
			}
			spec: {
				containers: [{
					command: [
						"sh",
						"-c",
						"echo \"Store setup completed\"",
					]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "done"
				}]
				initContainers: [{
					args: ["temporal-sql-tool setup-schema -v 0.0 && temporal-sql-tool update-schema --schema-dir /etc/temporal/schema/postgresql/v12/temporal/versioned"]
					command: [
						"sh",
						"-c",
					]
					env: [{
						name:  "SQL_PLUGIN"
						value: "postgres12_pgx"
					}, {
						name:  "SQL_HOST"
						value: "temporal-db-rw.temporal.svc"
					}, {
						name:  "SQL_PORT"
						value: "5432"
					}, {
						name:  "SQL_DATABASE"
						value: "temporal"
					}, {
						name:  "SQL_USER"
						value: "temporal"
					}, {
						name: "SQL_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "manage-schema-default-store"
					volumeMounts:    null
				}, {
					args: ["temporal-sql-tool setup-schema -v 0.0 && temporal-sql-tool update-schema --schema-dir /etc/temporal/schema/postgresql/v12/visibility/versioned"]
					command: [
						"sh",
						"-c",
					]
					env: [{
						name:  "SQL_PLUGIN"
						value: "postgres12_pgx"
					}, {
						name:  "SQL_HOST"
						value: "temporal-db-rw.temporal.svc"
					}, {
						name:  "SQL_PORT"
						value: "5432"
					}, {
						name:  "SQL_DATABASE"
						value: "temporal_visibility"
					}, {
						name:  "SQL_USER"
						value: "temporal"
					}, {
						name: "SQL_PASSWORD"
						valueFrom: secretKeyRef: {
							key:  "password"
							name: "temporal-db-app"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
					imagePullPolicy: "IfNotPresent"
					name:            "manage-schema-visibility-store"
					volumeMounts:    null
				}]
				restartPolicy:      "OnFailure"
				serviceAccountName: "default"
			}
		}
		ttlSecondsAfterFinished: 86400
	}
}
objects: Pod: "temporal-test-cluster-health": {
	apiVersion: "v1"
	kind:       "Pod"
	metadata: {
		annotations: "helm.sh/hook": "test"
		labels: {
			"app.kubernetes.io/component":  "test"
			"app.kubernetes.io/instance":   "temporal"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "temporal"
			"app.kubernetes.io/part-of":    "temporal"
			"app.kubernetes.io/version":    "1.31.0"
			"helm.sh/chart":                "temporal-1.2.0"
		}
		name: "temporal-test-cluster-health"
	}
	spec: {
		containers: [{
			command: [
				"temporal",
				"operator",
				"cluster",
				"health",
			]
			env: [{
				name:  "TEMPORAL_ADDRESS"
				value: "temporal-frontend:7233"
			}]
			image:           "host.k3d.internal:5000/mirror/temporalio/admin-tools:1.31.0"
			imagePullPolicy: "IfNotPresent"
			name:            "cluster-health"
		}]
		restartPolicy:      "Never"
		serviceAccountName: "default"
	}
}
