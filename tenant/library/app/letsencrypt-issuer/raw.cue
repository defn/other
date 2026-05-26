@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

_cluster_name:     string              @tag(cluster_name)
_account_id:       string              @tag(account_id)
_irsa_role_prefix: string              @tag(irsa_role_prefix)
_cluster_domain:   string              @tag(cluster_domain)
_dns_zone:         string              @tag(dns_zone)
_acme_endpoint:    *"prod" | "staging" @tag(acme_endpoint)

// ExternalSecret for Cloudflare API token (cert-manager namespace)
objects: ExternalSecret: "cloudflare-api-token": {
	apiVersion: "external-secrets.io/v1"
	kind:       "ExternalSecret"
	metadata: {
		name:      "cloudflare-api-token"
		namespace: "cert-manager"
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

// ClusterIssuer using Let's Encrypt staging with Cloudflare DNS01
objects: ClusterIssuer: "letsencrypt-staging": {
	apiVersion: "cert-manager.io/v1"
	kind:       "ClusterIssuer"
	metadata: name: "letsencrypt-staging"
	spec: acme: {
		server: "https://acme-staging-v02.api.letsencrypt.org/directory"
		email:  "iam@defn.sh"
		privateKeySecretRef: name: "letsencrypt-staging-account-key"
		solvers: [{
			dns01: cloudflare: apiTokenSecretRef: {
				name: "cloudflare-api-token"
				key:  "api-token"
			}
			selector: dnsZones: [_dns_zone]
		}]
	}
}

// ClusterIssuer using Let's Encrypt production with Cloudflare DNS01
objects: ClusterIssuer: "letsencrypt-prod": {
	apiVersion: "cert-manager.io/v1"
	kind:       "ClusterIssuer"
	metadata: name: "letsencrypt-prod"
	spec: acme: {
		server: "https://acme-v02.api.letsencrypt.org/directory"
		email:  "iam@defn.sh"
		privateKeySecretRef: name: "letsencrypt-prod-account-key"
		solvers: [{
			dns01: cloudflare: apiTokenSecretRef: {
				name: "cloudflare-api-token"
				key:  "api-token"
			}
			selector: dnsZones: [_dns_zone]
		}]
	}
}

// Wildcard certificate (cert-manager namespace, reflected to others by Kyverno).
// Issuer kind is selected per-cluster via acme_endpoint:
//   - "prod"    -> letsencrypt-prod    (real, browser-trusted; rate-limited)
//   - "staging" -> letsencrypt-staging (untrusted; suited for dev/test clusters)
objects: Certificate: "wildcard-cert": {
	apiVersion: "cert-manager.io/v1"
	kind:       "Certificate"
	metadata: {
		name:      "wildcard-cert"
		namespace: "cert-manager"
	}
	spec: {
		secretName: "wildcard-tls"
		issuerRef: {
			name: "letsencrypt-\(_acme_endpoint)"
			kind: "ClusterIssuer"
		}
		dnsNames: [
			_cluster_domain,
			"*." + _cluster_domain,
		]
		secretTemplate: labels: "defn.sh/reflect-tls": "true"
	}
}

// RBAC for Kyverno to manage Secrets (needed for generate/clone)
objects: ClusterRole: "kyverno-secret-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "kyverno-secret-manager"
	rules: [{
		apiGroups: [""]
		resources: ["secrets"]
		verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
	}]
}

objects: ClusterRoleBinding: "kyverno-secret-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "kyverno-secret-manager"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "kyverno-secret-manager"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "kyverno-background-controller"
		namespace: "kyverno"
	}, {
		kind:      "ServiceAccount"
		name:      "kyverno-admission-controller"
		namespace: "kyverno"
	}]
}

// Kyverno ClusterPolicy to copy wildcard-tls to namespaces that need it.
// One rule per target namespace (avoids templated namespace validation issue).
// Namespaces that need wildcard-tls copied from cert-manager.
_tls_namespaces: ["traefik", "argocd", "oauth2-proxy", "coder", "dex", "goldilocks", "riverqueue"]

objects: ClusterPolicy: "reflect-wildcard-tls": {
	apiVersion: "kyverno.io/v1"
	kind:       "ClusterPolicy"
	metadata: name: "reflect-wildcard-tls"
	spec: {
		admission:        true
		background:       true
		emitWarning:      false
		generateExisting: true
		rules: [
			for ns in _tls_namespaces {
				name:                   "copy-to-\(ns)"
				skipBackgroundRequests: false
				match: any: [{resources: {kinds: ["Secret"], names: ["wildcard-tls"], namespaces: ["cert-manager"]}}]
				generate: {
					synchronize: true
					apiVersion:  "v1"
					kind:        "Secret"
					name:        "wildcard-tls"
					namespace:   ns
					clone: {namespace: "cert-manager", name: "wildcard-tls"}
				}
			},
		]
	}
}
