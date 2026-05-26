@experiment(aliasv2,explicitopen,shortcircuit,try)

// tailscale_patch.cue -- generates per-cluster kustomize patch for tailscale expose.
// Adds tailscale.com/hostname annotation with the cluster name.
package k8s

_cluster_name: string @tag(cluster_name)
_service_name: string @tag(service_name)
_service_ns:   string @tag(service_ns)

tailscale_patch: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      _service_name
		namespace: _service_ns
		annotations: {
			"tailscale.com/expose":   "true"
			"tailscale.com/hostname": _cluster_name
		}
	}
}
