@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["buildbuddy.bbcr.io/public/buildbuddy-app-onprem"]

kustomize_patches: [{
	target: {
		kind: "Secret"
		name: "buildbuddy-config"
	}
	patch: """
		$patch: delete
		apiVersion: v1
		kind: Secret
		metadata:
		  name: buildbuddy-config
		"""
}]

// Secrets managed by External Secrets Operator.
secrets: "buildbuddy-config": {
	// BuildBuddy config.yaml with database DSN, cache paths, SSL settings.
	"config.yaml": string
}
