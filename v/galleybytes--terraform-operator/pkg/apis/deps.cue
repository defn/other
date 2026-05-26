@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1:v1beta1",
	"@io_k8s_apimachinery//pkg/runtime:runtime",
]
