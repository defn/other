@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"ghcr.io/projectcapsule/capsule",
	"docker.io/clastix/kubectl",
]

helm_values: {
	certManager: generateCertificates: true
	tls: create:                       false
}

kustomize_patches: [{
	target: {
		kind: "Secret"
		name: "capsule-tls"
	}
	patch: """
		$patch: delete
		apiVersion: v1
		kind: Secret
		metadata:
		  name: capsule-tls
		"""
}]
