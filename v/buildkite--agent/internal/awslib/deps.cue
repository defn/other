@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_aws_aws_sdk_go_v2//aws",
	"@com_github_aws_aws_sdk_go_v2_config//:config",
	"@com_github_aws_aws_sdk_go_v2_feature_ec2_imds//:imds",
]
