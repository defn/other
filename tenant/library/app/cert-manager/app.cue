// TLS certificate management
@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"quay.io/jetstack/cert-manager-controller",
	"quay.io/jetstack/cert-manager-cainjector",
	"quay.io/jetstack/cert-manager-webhook",
	"quay.io/jetstack/cert-manager-startupapicheck",
]

helm_values: {
	crds: enabled: true
	// Use public recursive nameservers for DNS01 ACME challenge validation.
	// Cluster DNS can't resolve external domains. Default matches Cloudflare.
	dns01RecursiveNameserversOnly: true
	dns01RecursiveNameservers:     "1.1.1.1:53,8.8.8.8:53"
}
