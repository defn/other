@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1:v1beta1",
	"@io_k8s_client_go//discovery:discovery",
	"@io_k8s_client_go//rest:rest",
	"@io_k8s_client_go//util/flowcontrol:flowcontrol",
]
