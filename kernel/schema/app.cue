@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

#AppKind: "kustomize" | "raw"

#App: {
	name:  string
	kind:  #AppKind
	path:  string // workspace-relative (e.g. "tenant/library/app/argocd")
	desc?: string

	// kustomize apps: helm chart fields
	if kind == "kustomize" {
		chart_name:    string
		chart_repo:    string
		chart_version: string
		chart_sha256:  string
		// Which k8s version dir to use for the canonical gen-app.cue and helm chart.
		// Defaults to k8s-a (cluster a -- k3s stable); override per-app if a chart
		// renders incorrectly on newer k8s API versions.
		k8s_version_dir: *"k8s-a" | =~"^k8s-[a-z]$"
	}

	// stamp_args records the arguments used by `defn stamp helmapp` to create
	// this app entry. Enables mechanical idempotency verification.
	stamp_args?: {
		chart_repo:    string
		chart_name:    string
		chart_version: string
	}
}

// #AppConfig defines the per-app hand-edited config in app/<name>/app.cue.
// Contains all app-specific content: helm values, patches, images,
// secret/route mappings, and any CUE overlay objects.
#AppConfig: {
	// Helm release namespace (defaults to app name if omitted).
	namespace?: string

	// Source container images used by this app. Gen matches these against
	// catalog/mirrors.cue to produce kustomize image rewrites.
	images?: [...string]

	// Helm values override passed as valuesInline in kustomization.yaml.
	helm_values?: _

	// Kustomize strategic merge patches.
	kustomize_patches?: [...]

	// Extra helmCharts options (e.g. includeCRDs: true).
	helm_options?: _

	// ESO secret mappings (cluster-scoped apps).
	secret_mappings?: [string]: {
		namespace: string
		keys: [string]: string
	}

	// Traefik IngressRoute mappings (cluster-scoped apps).
	route_mappings?: [string]: {
		namespace:     string
		host:          string
		service:       string
		port:          *80 | number
		auth:          *true | bool
		service_kind?: string
	}

	// Workload inventory for monitoring.
	workloads?: [string]: {
		kind:       "Deployment" | "StatefulSet" | "DaemonSet"
		namespace:  string
		container:  string
		replicas?:  number
		resources?: _
	}
}
