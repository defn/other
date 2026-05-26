@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"registry.k8s.io/autoscaling/vpa-recommender",
	"registry.k8s.io/autoscaling/vpa-updater",
	"registry.k8s.io/autoscaling/vpa-admission-controller",
	"alpine/kubectl",
	"registry.k8s.io/ingress-nginx/kube-webhook-certgen",
]
