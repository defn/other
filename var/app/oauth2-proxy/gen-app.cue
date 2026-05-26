@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

objects: ServiceAccount: "oauth2-proxy": {
	apiVersion:                   "v1"
	automountServiceAccountToken: true
	kind:                         "ServiceAccount"
	metadata: {
		labels: {
			app:                            "oauth2-proxy"
			"app.kubernetes.io/component":  "authentication-proxy"
			"app.kubernetes.io/instance":   "oauth2-proxy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "oauth2-proxy"
			"app.kubernetes.io/part-of":    "oauth2-proxy"
			"app.kubernetes.io/version":    "7.15.2"
			"helm.sh/chart":                "oauth2-proxy-10.6.0"
		}
		name:      "oauth2-proxy"
		namespace: "oauth2-proxy"
	}
}
objects: ConfigMap: "oauth2-proxy": {
	apiVersion: "v1"
	data: "oauth2_proxy.cfg": """

		provider = "oidc"
		provider_display_name = "Dex"
		client_id = "oauth2-proxy"
		email_domains = [ "defn.sh" ]
		scope = "openid profile email groups"
		oidc_groups_claim = "groups"
		cookie_secure = true
		cookie_httponly = true
		cookie_samesite = "lax"
		cookie_expire = "12h"
		cookie_refresh = "1h"
		cookie_csrf_per_request = false
		cookie_csrf_expire = "15m"
		ssl_insecure_skip_verify = true
		upstreams = [ "static://202" ]
		reverse_proxy = true
		set_xauthrequest = true
		pass_user_headers = true
		session_store_type = "redis"
		redis_connection_url = "redis://redis.oauth2-proxy.svc.cluster.local:6379"

		"""
	kind: "ConfigMap"
	metadata: {
		labels: {
			app:                            "oauth2-proxy"
			"app.kubernetes.io/component":  "authentication-proxy"
			"app.kubernetes.io/instance":   "oauth2-proxy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "oauth2-proxy"
			"app.kubernetes.io/part-of":    "oauth2-proxy"
			"app.kubernetes.io/version":    "7.15.2"
			"helm.sh/chart":                "oauth2-proxy-10.6.0"
		}
		name:      "oauth2-proxy"
		namespace: "oauth2-proxy"
	}
}
objects: Service: "oauth2-proxy": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			app:                            "oauth2-proxy"
			"app.kubernetes.io/component":  "authentication-proxy"
			"app.kubernetes.io/instance":   "oauth2-proxy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "oauth2-proxy"
			"app.kubernetes.io/part-of":    "oauth2-proxy"
			"app.kubernetes.io/version":    "7.15.2"
			"helm.sh/chart":                "oauth2-proxy-10.6.0"
		}
		name:      "oauth2-proxy"
		namespace: "oauth2-proxy"
	}
	spec: {
		ports: [{
			appProtocol: "http"
			name:        "http"
			port:        80
			protocol:    "TCP"
			targetPort:  "http"
		}, {
			appProtocol: "http"
			name:        "metrics"
			port:        44180
			protocol:    "TCP"
			targetPort:  "metrics"
		}]
		selector: {
			"app.kubernetes.io/instance": "oauth2-proxy"
			"app.kubernetes.io/name":     "oauth2-proxy"
		}
		type: "ClusterIP"
	}
}
objects: Deployment: "oauth2-proxy": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			app:                            "oauth2-proxy"
			"app.kubernetes.io/component":  "authentication-proxy"
			"app.kubernetes.io/instance":   "oauth2-proxy"
			"app.kubernetes.io/managed-by": "Helm"
			"app.kubernetes.io/name":       "oauth2-proxy"
			"app.kubernetes.io/part-of":    "oauth2-proxy"
			"app.kubernetes.io/version":    "7.15.2"
			"helm.sh/chart":                "oauth2-proxy-10.6.0"
		}
		name:      "oauth2-proxy"
		namespace: "oauth2-proxy"
	}
	spec: {
		replicas:             1
		revisionHistoryLimit: 10
		selector: matchLabels: {
			"app.kubernetes.io/instance": "oauth2-proxy"
			"app.kubernetes.io/name":     "oauth2-proxy"
		}
		template: {
			metadata: {
				annotations: {
					"checksum/config":        "29d2f6cbd7024c13beb3537a5ce4e18964ff85ccd1092c7653291794ed2c7648"
					"checksum/google-secret": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
					"checksum/redis-secret":  "01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b"
					"checksum/secret":        "9eb46bbdefd5cf844a2c4965b1241a7177addaa7c07789e7873ccda6b0104111"
				}
				labels: {
					app:                            "oauth2-proxy"
					"app.kubernetes.io/component":  "authentication-proxy"
					"app.kubernetes.io/instance":   "oauth2-proxy"
					"app.kubernetes.io/managed-by": "Helm"
					"app.kubernetes.io/name":       "oauth2-proxy"
					"app.kubernetes.io/part-of":    "oauth2-proxy"
					"app.kubernetes.io/version":    "7.15.2"
					"helm.sh/chart":                "oauth2-proxy-10.6.0"
				}
			}
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--http-address=0.0.0.0:4180",
						"--https-address=0.0.0.0:4443",
						"--metrics-address=0.0.0.0:44180",
						"--config=/etc/oauth2_proxy/oauth2_proxy.cfg",
					]
					env: [{
						name: "OAUTH2_PROXY_CLIENT_ID"
						valueFrom: secretKeyRef: {
							key:  "client-id"
							name: "oauth2-proxy"
						}
					}, {
						name: "OAUTH2_PROXY_CLIENT_SECRET"
						valueFrom: secretKeyRef: {
							key:  "client-secret"
							name: "oauth2-proxy"
						}
					}, {
						name: "OAUTH2_PROXY_COOKIE_SECRET"
						valueFrom: secretKeyRef: {
							key:  "cookie-secret"
							name: "oauth2-proxy"
						}
					}, {
						name:  "OAUTH2_PROXY_SESSION_STORE_TYPE"
						value: "redis"
					}, {
						name:  "OAUTH2_PROXY_REDIS_CONNECTION_URL"
						value: "redis://redis.oauth2-proxy.svc.cluster.local:6379"
					}]
					image:           "host.k3d.internal:5000/mirror/quay.io/oauth2-proxy/oauth2-proxy:v7.15.2"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						httpGet: {
							path:   "/ping"
							port:   "http"
							scheme: "HTTP"
						}
						initialDelaySeconds: 0
						timeoutSeconds:      1
					}
					name: "oauth2-proxy"
					ports: [{
						containerPort: 4180
						name:          "http"
						protocol:      "TCP"
					}, {
						containerPort: 44180
						name:          "metrics"
						protocol:      "TCP"
					}]
					readinessProbe: {
						httpGet: {
							path:   "/ready"
							port:   "http"
							scheme: "HTTP"
						}
						initialDelaySeconds: 0
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      5
					}
					resources: {}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
						runAsGroup:             2000
						runAsNonRoot:           true
						runAsUser:              2000
						seccompProfile: type: "RuntimeDefault"
					}
					volumeMounts: [{
						mountPath: "/etc/oauth2_proxy/oauth2_proxy.cfg"
						name:      "configmain"
						subPath:   "oauth2_proxy.cfg"
					}]
				}]
				enableServiceLinks: true
				serviceAccountName: "oauth2-proxy"
				volumes: [{
					configMap: {
						defaultMode: 420
						name:        "oauth2-proxy"
					}
					name: "configmain"
				}]
			}
		}
	}
}
