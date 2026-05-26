@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/buildkite--agent/api",
	"//v/buildkite--agent/internal/agenthttp",
	"//v/buildkite--agent/internal/awslib",
	"//v/buildkite--agent/internal/experiments",
	"//v/buildkite--agent/internal/mime",
	"//v/buildkite--agent/internal/osutil",
	"//v/buildkite--agent/logger",
	"//v/buildkite--agent/version",
	"@com_github_azure_azure_sdk_for_go_sdk_azidentity//:azidentity",
	"@com_github_azure_azure_sdk_for_go_sdk_storage_azblob//:azblob",
	"@com_github_azure_azure_sdk_for_go_sdk_storage_azblob//sas",
	"@com_github_azure_azure_sdk_for_go_sdk_storage_azblob//service",
	"@com_github_aws_aws_sdk_go_v2//aws",
	"@com_github_aws_aws_sdk_go_v2_config//:config",
	"@com_github_aws_aws_sdk_go_v2_feature_s3_manager//:manager",
	"@com_github_aws_aws_sdk_go_v2_service_s3//:s3",
	"@com_github_aws_aws_sdk_go_v2_service_s3//types",
	"@com_github_aws_smithy_go//transport/http",
	"@com_github_buildkite_roko//:roko",
	"@com_github_dustin_go_humanize//:go-humanize",
	"@dev_drjosh_zzglob//:zzglob",
	"@org_golang_google_api//googleapi",
	"@org_golang_google_api//option",
	"@org_golang_google_api//storage/v1:storage",
	"@org_golang_x_oauth2//google",
]
