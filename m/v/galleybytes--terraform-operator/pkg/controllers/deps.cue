@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1:v1beta1",
	"//v/galleybytes--terraform-operator/pkg/utils:utils",
	"@com_github_go_logr_logr//:logr",
	"@com_github_hashicorp_go_getter//:go-getter",
	"@com_github_makenowjust_heredoc//:heredoc",
	"@com_github_patrickmn_go_cache//:go-cache",
	"@io_k8s_api//apps/v1:apps",
	"@io_k8s_api//batch/v1:batch",
	"@io_k8s_api//core/v1:core",
	"@io_k8s_api//rbac/v1:rbac",
	"@io_k8s_apimachinery//pkg/api/errors:errors",
	"@io_k8s_apimachinery//pkg/api/resource:resource",
	"@io_k8s_apimachinery//pkg/apis/meta/v1:meta",
	"@io_k8s_apimachinery//pkg/fields:fields",
	"@io_k8s_apimachinery//pkg/labels:labels",
	"@io_k8s_apimachinery//pkg/runtime:runtime",
	"@io_k8s_apimachinery//pkg/types:types",
	"@io_k8s_apimachinery//pkg/util/uuid:uuid",
	"@io_k8s_client_go//tools/record:record",
	"@io_k8s_sigs_controller_runtime//:controller-runtime",
	"@io_k8s_sigs_controller_runtime//pkg/client:client",
	"@io_k8s_sigs_controller_runtime//pkg/controller/controllerutil:controllerutil",
	"@io_k8s_sigs_controller_runtime//pkg/controller:controller",
	"@io_k8s_sigs_controller_runtime//pkg/reconcile:reconcile",
]
