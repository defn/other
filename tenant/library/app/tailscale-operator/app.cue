@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "tailscale"
images: ["tailscale/k8s-operator"]

// overlay.cue -- per-cluster objects for Tailscale operator.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// Generate ExternalSecrets from secret_mappings (defined in secrets.cue)
objects: ExternalSecret: {
	for secretName, mapping in secret_mappings {
		(secretName): {
			apiVersion: "external-secrets.io/v1"
			kind:       "ExternalSecret"
			metadata: {
				name:      secretName
				namespace: mapping.namespace
			}
			spec: {
				refreshInterval: "1h"
				secretStoreRef: {
					name: "aws-secrets-manager"
					kind: "ClusterSecretStore"
				}
				target: name: secretName
				data: [
					for k8sKey, awsProp in mapping.keys {
						secretKey: k8sKey
						remoteRef: {
							key:                "defn/\(_cluster_name)-secrets"
							property:           awsProp
							conversionStrategy: "Default"
							decodingStrategy:   "None"
							metadataPolicy:     "None"
						}
					},
				]
			}
		}
	}
}

// Secrets managed by External Secrets Operator.
secrets: "operator-oauth": {
	client_id:     string
	client_secret: string
}

// ESO mappings: K8s secret key -> AWS Secrets Manager property name.
secret_mappings: [string]: {
	namespace: string
	keys: [string]: string
}

secret_mappings: "operator-oauth": {
	namespace: "tailscale"
	keys: {
		client_id:     "tailscale-oauth-client-id"
		client_secret: "tailscale-oauth-client-secret"
	}
}

// Workload inventory.
workloads: [string]: {
	kind:      "Deployment" | "StatefulSet" | "DaemonSet"
	namespace: string
	container: string
	replicas?: number
	resources?: {
		requests?: {cpu?: string, memory?: string}
		limits?: {cpu?: string, memory?: string}
	}
}

workloads: operator: {
	kind:      "Deployment"
	namespace: "tailscale"
	container: "operator"
	replicas:  1
}
