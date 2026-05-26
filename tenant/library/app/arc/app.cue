@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "arc-systems"
images: ["ghcr.io/actions/gha-runner-scale-set-controller"]
helm_options: includeCRDs: true
