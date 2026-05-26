@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "linkerd"
images: [
	"cr.l5d.io/linkerd/controller",
	"cr.l5d.io/linkerd/policy-controller",
	"cr.l5d.io/linkerd/proxy",
	"cr.l5d.io/linkerd/proxy-init",
]

helm_values: {
	// Static placeholder -- cert-manager provides real certs at runtime.
	// Without this, Helm generates random trust anchors on every render,
	// causing checksum/config annotations to change non-deterministically.
	identityTrustAnchorsPEM: "placeholder-for-deterministic-render"
	heartbeatSchedule:       "0 8 * * *"
	identity: {
		externalCA: true
		issuer: scheme: "kubernetes.io/tls"
	}
	proxyInjector: {
		externalSecret: true
		caBundle:       "placeholder"
	}
	profileValidator: {
		externalSecret: true
		caBundle:       "placeholder"
	}
	policyValidator: {
		externalSecret: true
		caBundle:       "placeholder"
	}
}

_delete_secret_patch: {
	_name: string
	target: {
		kind: "Secret"
		name: _name
	}
	patch: """
		$patch: delete
		apiVersion: v1
		kind: Secret
		metadata:
		  name: \(_name)
		"""
}

_clear_ca_bundle_patch: {
	_name: string
	_kind: string
	target: {
		kind: _kind
		name: _name
	}
	patch: """
		- op: replace
		  path: /webhooks/0/clientConfig/caBundle
		  value: ""
		"""
}

kustomize_patches: [
	// Delete all webhook TLS secrets -- cert-manager injects certs at runtime.
	_delete_secret_patch & {_name: "linkerd-policy-validator-k8s-tls"},
	_delete_secret_patch & {_name: "linkerd-proxy-injector-k8s-tls"},
	_delete_secret_patch & {_name: "linkerd-sp-validator-k8s-tls"},
	// Strip generated caBundle from webhook configs -- cert-manager injects via
	// cert-manager.io/inject-ca-from annotation at deploy time.
	_clear_ca_bundle_patch & {_kind: "MutatingWebhookConfiguration", _name: "linkerd-proxy-injector-webhook-config"},
	_clear_ca_bundle_patch & {_kind: "ValidatingWebhookConfiguration", _name: "linkerd-policy-validator-webhook-config"},
	_clear_ca_bundle_patch & {_kind: "ValidatingWebhookConfiguration", _name: "linkerd-sp-validator-webhook-config"},
]
