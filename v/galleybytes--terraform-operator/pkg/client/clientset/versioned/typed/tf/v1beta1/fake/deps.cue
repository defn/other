@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1:v1beta1",
	"//v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1:v1beta1",
	"@io_k8s_apimachinery//pkg/apis/meta/v1:meta",
	"@io_k8s_apimachinery//pkg/labels:labels",
	"@io_k8s_apimachinery//pkg/types:types",
	"@io_k8s_apimachinery//pkg/watch:watch",
	"@io_k8s_client_go//rest:rest",
	"@io_k8s_client_go//testing:testing",
]
