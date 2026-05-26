@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1:v1beta1",
	"//v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1/fake:fake",
	"//v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1:v1beta1",
	"//v/galleybytes--terraform-operator/pkg/client/clientset/versioned:versioned",
	"@io_k8s_apimachinery//pkg/apis/meta/v1:meta",
	"@io_k8s_apimachinery//pkg/runtime/schema:schema",
	"@io_k8s_apimachinery//pkg/runtime/serializer:serializer",
	"@io_k8s_apimachinery//pkg/runtime:runtime",
	"@io_k8s_apimachinery//pkg/util/runtime:runtime",
	"@io_k8s_apimachinery//pkg/watch:watch",
	"@io_k8s_client_go//discovery/fake:fake",
	"@io_k8s_client_go//discovery:discovery",
	"@io_k8s_client_go//testing:testing",
]
