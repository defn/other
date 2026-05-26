@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

images: [
	"reg.kyverno.io/kyverno/kyverno",
	"reg.kyverno.io/kyverno/kyvernopre",
	"reg.kyverno.io/kyverno/background-controller",
	"reg.kyverno.io/kyverno/cleanup-controller",
	"reg.kyverno.io/kyverno/reports-controller",
	"reg.kyverno.io/kyverno/kyverno-cli",
	"ghcr.io/kyverno/readiness-checker",
	"registry.k8s.io/kubectl",
]
