@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_aws_aws_sdk_go_v2//aws",
	"@com_github_aws_aws_sdk_go_v2_service_kms//:kms",
	"@com_github_aws_aws_sdk_go_v2_service_kms//types",
	"@com_github_lestrrat_go_jwx_v2//jwa",
]
