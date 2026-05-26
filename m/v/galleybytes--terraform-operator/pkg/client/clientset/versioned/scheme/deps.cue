@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1:v1beta1",
	"@io_k8s_apimachinery//pkg/apis/meta/v1:meta",
	"@io_k8s_apimachinery//pkg/runtime/schema:schema",
	"@io_k8s_apimachinery//pkg/runtime/serializer:serializer",
	"@io_k8s_apimachinery//pkg/runtime:runtime",
	"@io_k8s_apimachinery//pkg/util/runtime:runtime",
]
