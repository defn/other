// Automatic DNS from ingress annotations
@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: ["registry.k8s.io/external-dns/external-dns"]

helm_values: env: [{
	name: "AWS_ACCESS_KEY_ID"
	valueFrom: secretKeyRef: {
		name:     "aws-credentials"
		key:      "access-key-id"
		optional: true
	}
}, {
	name: "AWS_SECRET_ACCESS_KEY"
	valueFrom: secretKeyRef: {
		name:     "aws-credentials"
		key:      "secret-access-key"
		optional: true
	}
}, {
	name: "AWS_SESSION_TOKEN"
	valueFrom: secretKeyRef: {
		name:     "aws-credentials"
		key:      "session-token"
		optional: true
	}
}]
