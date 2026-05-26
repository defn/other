@experiment(aliasv2,explicitopen,shortcircuit,try)

package test_deps

test_deps: [
	"@io_k8s_sigs_controller_runtime//pkg/client/fake:fake",
]
