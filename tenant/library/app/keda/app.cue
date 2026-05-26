// Event-driven autoscaling
@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"ghcr.io/kedacore/keda",
	"ghcr.io/kedacore/keda-metrics-apiserver",
	"ghcr.io/kedacore/keda-admission-webhooks",
]
