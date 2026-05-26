@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #SecretMapping declares how a K8s Secret maps to AWS Secrets Manager properties.
// Used by apps to declare their secret requirements and generate ExternalSecrets.
#SecretMapping: {
	// namespace for the generated ExternalSecret
	namespace: string
	// keys maps K8s secret key -> AWS Secrets Manager property name
	keys: [string]: string
}
