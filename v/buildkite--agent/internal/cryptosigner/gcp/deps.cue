@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_lestrrat_go_jwx_v2//jwa",
	"@com_google_cloud_go_kms//apiv1",
	"@com_google_cloud_go_kms//apiv1/kmspb",
	"@org_golang_google_api//option",
	"@org_golang_google_protobuf//types/known/wrapperspb",
]
