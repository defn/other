@experiment(aliasv2,explicitopen,shortcircuit,try)

// app.cue -- app inventory re-exported from catalog for gen-app.clj.
package app

import (
	"github.com/defn/other/kernel/catalog"
	"github.com/defn/other/kernel/schema"
)

// Re-export app map from catalog (source of truth).
apps: catalog.apps

// K8s version map for gen-app.clj versioned generation.
// Keys are cluster letters; values track per-cluster k3s pins in versions.cue.
k8s_versions: {
	"k8s-a": schema.versions.k8s_a.version
	"k8s-b": schema.versions.k8s_b.version
	"k8s-c": schema.versions.k8s_c.version
}
