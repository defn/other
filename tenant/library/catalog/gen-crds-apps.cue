@experiment(aliasv2,explicitopen,shortcircuit,try)

// gen-crds-apps.cue -- CRD companion apps, one per kustomize app that has CRDs.
// Manually maintained. When adding a new kustomize app with CRDs, add its
// -crds companion here.
//
// The gen pipeline splits CRDs from the parent app's gen-app.cue into the
// -crds app's gen-app.cue during the sync step.
package catalog

import "github.com/defn/other/kernel/schema"

apps: [string]: schema.#App

apps: {
	"arc-crds": {
		name: "arc-crds"
		kind: "raw"
		path: "tenant/library/app/arc-crds"
		desc: "Actions Runner Controller CRDs"
	}
	"argo-rollouts-crds": {
		name: "argo-rollouts-crds"
		kind: "raw"
		path: "tenant/library/app/argo-rollouts-crds"
		desc: "Argo Rollouts CRDs"
	}
	"argocd-crds": {
		name: "argocd-crds"
		kind: "raw"
		path: "tenant/library/app/argocd-crds"
		desc: "ArgoCD CRDs"
	}
	"cert-manager-crds": {
		name: "cert-manager-crds"
		kind: "raw"
		path: "tenant/library/app/cert-manager-crds"
		desc: "cert-manager CRDs"
	}
	"cloudnative-pg-crds": {
		name: "cloudnative-pg-crds"
		kind: "raw"
		path: "tenant/library/app/cloudnative-pg-crds"
		desc: "CloudNativePG CRDs"
	}
	"external-secrets-crds": {
		name: "external-secrets-crds"
		kind: "raw"
		path: "tenant/library/app/external-secrets-crds"
		desc: "External Secrets Operator CRDs"
	}
	"k3k-crds": {
		name: "k3k-crds"
		kind: "raw"
		path: "tenant/library/app/k3k-crds"
		desc: "k3k CRDs (Cluster, VirtualClusterPolicy)"
	}
	"keda-crds": {
		name: "keda-crds"
		kind: "raw"
		path: "tenant/library/app/keda-crds"
		desc: "KEDA CRDs"
	}
	"kyverno-crds": {
		name: "kyverno-crds"
		kind: "raw"
		path: "tenant/library/app/kyverno-crds"
		desc: "Kyverno CRDs"
	}
	"tailscale-operator-crds": {
		name: "tailscale-operator-crds"
		kind: "raw"
		path: "tenant/library/app/tailscale-operator-crds"
		desc: "Tailscale Operator CRDs"
	}
	"topolvm-crds": {
		name: "topolvm-crds"
		kind: "raw"
		path: "tenant/library/app/topolvm-crds"
		desc: "TopoLVM CRDs"
	}
	"redis-operator-crds": {
		name: "redis-operator-crds"
		kind: "raw"
		path: "tenant/library/app/redis-operator-crds"
		desc: "Redis Operator CRDs"
	}
	"terraform-operator-crds": {
		name: "terraform-operator-crds"
		kind: "raw"
		path: "tenant/library/app/terraform-operator-crds"
		desc: "Terraform Operator CRDs"
	}
	"trust-manager-crds": {
		name: "trust-manager-crds"
		kind: "raw"
		path: "tenant/library/app/trust-manager-crds"
		desc: "trust-manager CRDs"
	}
}
