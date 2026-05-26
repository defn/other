@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #IRSABinding declares that an app needs an IRSA role in each cluster.
#IRSABinding: {
	workload:        string // role suffix: defn-tmp-<cluster>-<workload>
	service_account: string // full SA ref: system:serviceaccount:<ns>:<name>
	policies: [...string] // IAM policy ARNs to attach
}

// #IRSAContainer adds IRSA env vars and volume mount to a container spec.
#IRSAContainer: {
	_irsa_role_arn: string
	_irsa_audience: *"sts.amazonaws.com" | string

	env: [{
		name:  "AWS_ROLE_ARN"
		value: _irsa_role_arn
	}, {
		name:  "AWS_WEB_IDENTITY_TOKEN_FILE"
		value: "/var/run/secrets/irsa/token"
	}]
	volumeMounts: [{
		name:      "irsa-token"
		mountPath: "/var/run/secrets/irsa"
		readOnly:  true
	}]
}

// #IRSAVolume is the projected SA token volume for IRSA.
#IRSAVolume: {
	_irsa_audience: *"sts.amazonaws.com" | string

	name: "irsa-token"
	projected: sources: [{
		serviceAccountToken: {
			audience:          _irsa_audience
			expirationSeconds: 86400
			path:              "token"
		}
	}]
}
