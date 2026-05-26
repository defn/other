@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

#K8sPlatformKind: "k3d" | "eks" | "rke2"

#PlatformApp: {
	namespace?: string // override target namespace
	// Every app renders per-cluster. Overlays below customize per (app, cluster);
	// apps without overlays get an identity overlay (byte-identical YAML).
	irsa?:         #IRSAOverlay
	domain_patch?: bool // if true, apply domain-specific kustomize patch
	tailscale_expose?: {// expose a Service via tailscale with per-cluster hostname
		service:   string // k8s Service name to annotate
		namespace: string // Service namespace
	}
}

#IRSAOverlay: {
	workload:        string // IRSA role suffix + irsa_bindings key
	deployment_name: string // k8s Deployment name to patch
	container_name:  string // container name in the Deployment
	sa_name:         string // ServiceAccount name to annotate
}

#K8sPlatform: {
	name: string
	kind: #K8sPlatformKind
	path: string // workspace-relative, e.g. tenant/<owner>/k8s/<platform>
	apps: {[string]: #PlatformApp}
	desc?: string
}
