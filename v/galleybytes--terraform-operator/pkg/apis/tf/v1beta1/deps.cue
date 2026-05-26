@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@com_github_go_openapi_jsonreference//:jsonreference",
	"@io_k8s_api//core/v1:core",
	"@io_k8s_api//rbac/v1:rbac",
	"@io_k8s_apimachinery//pkg/api/resource:resource",
	"@io_k8s_apimachinery//pkg/apis/meta/v1:meta",
	"@io_k8s_apimachinery//pkg/runtime/schema:schema",
	"@io_k8s_apimachinery//pkg/runtime:runtime",
	"@io_k8s_kube_openapi//pkg/common:common",
	"@io_k8s_kube_openapi//pkg/validation/spec:spec",
	"@io_k8s_sigs_controller_runtime//pkg/scheme:scheme",
]
