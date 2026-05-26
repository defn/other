@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

_cluster_name:     string @tag(cluster_name)
_account_id:       string @tag(account_id)
_irsa_role_prefix: string @tag(irsa_role_prefix)
_cluster_domain:   string @tag(cluster_domain)
_dns_zone:         string @tag(dns_zone)

// ExternalSecret for Cloudflare API token
objects: ExternalSecret: "cloudflare-api-token": {
	apiVersion: "external-secrets.io/v1"
	kind:       "ExternalSecret"
	metadata: {
		name:      "cloudflare-api-token"
		namespace: "external-dns-cloudflare"
	}
	spec: {
		refreshInterval: "1h"
		secretStoreRef: {
			name: "aws-secrets-manager"
			kind: "ClusterSecretStore"
		}
		target: name: "cloudflare-api-token"
		data: [{
			secretKey: "api-token"
			remoteRef: {
				key:                "defn/\(_cluster_name)-secrets"
				property:           "cloudflare-api-token"
				conversionStrategy: "Default"
				decodingStrategy:   "None"
				metadataPolicy:     "None"
			}
		}]
	}
}

objects: ServiceAccount: "external-dns-cloudflare": {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      "external-dns-cloudflare"
		namespace: "external-dns-cloudflare"
	}
}

objects: ClusterRole: "external-dns-cloudflare": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "external-dns-cloudflare"
	rules: [{
		apiGroups: ["externaldns.k8s.io"]
		resources: ["dnsendpoints"]
		verbs: ["get", "watch", "list"]
	}, {
		apiGroups: ["externaldns.k8s.io"]
		resources: ["dnsendpoints/status"]
		verbs: ["update", "patch"]
	}]
}

objects: ClusterRoleBinding: "external-dns-cloudflare": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "external-dns-cloudflare"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "external-dns-cloudflare"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "external-dns-cloudflare"
		namespace: "external-dns-cloudflare"
	}]
}

objects: Service: "external-dns-cloudflare": {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "external-dns-cloudflare"
		namespace: "external-dns-cloudflare"
	}
	spec: {
		ports: [{
			name:       "http"
			port:       7979
			protocol:   "TCP"
			targetPort: "http"
		}]
		selector: "app.kubernetes.io/name": "external-dns-cloudflare"
		type: "ClusterIP"
	}
}

objects: Deployment: "external-dns-cloudflare": {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      "external-dns-cloudflare"
		namespace: "external-dns-cloudflare"
	}
	spec: {
		replicas: 1
		selector: matchLabels: "app.kubernetes.io/name": "external-dns-cloudflare"
		strategy: type: "Recreate"
		template: {
			metadata: labels: "app.kubernetes.io/name": "external-dns-cloudflare"
			spec: {
				automountServiceAccountToken: true
				containers: [{
					args: [
						"--log-level=info",
						"--log-format=text",
						"--interval=1m",
						"--source=crd",
						"--provider=cloudflare",
						"--domain-filter=\(_dns_zone)",
						"--policy=sync",
						"--registry=txt",
						"--txt-owner-id=\(_cluster_name)",
					]
					env: [{
						name: "CF_API_TOKEN"
						valueFrom: secretKeyRef: {
							name: "cloudflare-api-token"
							key:  "api-token"
						}
					}]
					image:           "host.k3d.internal:5000/mirror/registry.k8s.io/external-dns/external-dns:v0.20.0"
					imagePullPolicy: "IfNotPresent"
					livenessProbe: {
						failureThreshold: 2
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 10
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      5
					}
					name: "external-dns-cloudflare"
					ports: [{
						containerPort: 7979
						name:          "http"
						protocol:      "TCP"
					}]
					readinessProbe: {
						failureThreshold: 6
						httpGet: {
							path: "/healthz"
							port: "http"
						}
						initialDelaySeconds: 5
						periodSeconds:       10
						successThreshold:    1
						timeoutSeconds:      5
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
				securityContext: {
					fsGroup:      65534
					runAsNonRoot: true
					seccompProfile: type: "RuntimeDefault"
				}
				serviceAccountName: "external-dns-cloudflare"
			}
		}
	}
}
