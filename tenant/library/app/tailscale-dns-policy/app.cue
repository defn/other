@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

_cluster_name:     string @tag(cluster_name)
_account_id:       string @tag(account_id)
_irsa_role_prefix: string @tag(irsa_role_prefix)
_cluster_domain:   string @tag(cluster_domain)
_dns_zone:         string @tag(dns_zone)

// RBAC for Kyverno to manage DNSEndpoint resources (needed for generate)
objects: ClusterRole: "kyverno-dnsendpoint-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: name: "kyverno-dnsendpoint-manager"
	rules: [{
		apiGroups: ["externaldns.k8s.io"]
		resources: ["dnsendpoints"]
		verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
	}]
}

objects: ClusterRoleBinding: "kyverno-dnsendpoint-manager": {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: name: "kyverno-dnsendpoint-manager"
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "kyverno-dnsendpoint-manager"
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

// Kyverno ClusterPolicy to generate DNSEndpoint from Tailscale proxy Secret.
// When the Tailscale operator exposes Traefik, it creates a Secret with the
// device's Tailscale IP. This policy watches that Secret and generates a
// DNSEndpoint CR so ExternalDNS (Cloudflare) creates *.<cluster>.d3fn.com.
objects: ClusterPolicy: "tailscale-dns-endpoint": {
	apiVersion: "kyverno.io/v1"
	kind:       "ClusterPolicy"
	metadata: name: "tailscale-dns-endpoint"
	spec: {
		admission:        true
		background:       true
		emitWarning:      false
		generateExisting: true
		rules: [{
			name:                   "generate-wildcard-dns"
			skipBackgroundRequests: false
			match: any: [{
				resources: {
					kinds: ["Secret"]
					namespaces: ["tailscale"]
					selector: matchLabels: {
						"tailscale.com/parent-resource":      "traefik"
						"tailscale.com/parent-resource-type": "svc"
					}
				}
			}]
			context: [{
				name: "tailscaleIPv4"
				variable: jmesPath: "base64_decode(request.object.data.device_ips) | parse_json(@) | [?contains(@, '.')] | [0]"
			}]
			generate: {
				synchronize: true
				apiVersion:  "externaldns.k8s.io/v1alpha1"
				kind:        "DNSEndpoint"
				name:        "tailscale-wildcard"
				namespace:   "external-dns-cloudflare"
				data: spec: endpoints: [{
					dnsName:    "*." + _cluster_domain
					recordType: "A"
					recordTTL:  300
					targets: ["{{tailscaleIPv4}}"]
				}]
			}
		}]
	}
}
