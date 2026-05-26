@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

namespace: "kube-system"
images: ["public.ecr.aws/karpenter/controller"]

helm_values: settings: clusterName: "placeholder"
