@experiment(aliasv2,explicitopen,shortcircuit,try)

// domain_patch.cue -- generates per-cluster kustomize patches for domain config.
// Used by oauth2-proxy to inject redirect URL, cookie domain, whitelist domain.
package k8s

_cluster_domain: string @tag(cluster_domain)

// oauth2-proxy Deployment patch -- add domain-specific CLI args.
// Must include ALL args since strategic merge replaces the list.
oauth2_proxy_patch: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      "oauth2-proxy"
		namespace: "oauth2-proxy"
	}
	spec: template: spec: containers: [{
		name: "oauth2-proxy"
		args: [
			"--http-address=0.0.0.0:4180",
			"--config=/etc/oauth2_proxy/oauth2_proxy.cfg",
			"--redirect-url=https://auth.\(_cluster_domain)/oauth2/callback",
			"--whitelist-domain=.\(_cluster_domain)",
			"--cookie-domain=.\(_cluster_domain)",
			"--oidc-issuer-url=http://dex.dex.svc.cluster.local:5556",
			"--insecure-oidc-skip-issuer-verification=true",
			"--login-url=https://dex.\(_cluster_domain)/auth?connector_id=google",
			"--skip-provider-button=true",
		]
	}]
}
