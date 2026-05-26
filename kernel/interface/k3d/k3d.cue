@experiment(aliasv2,explicitopen,shortcircuit,try)

// k3d.cue -- cluster inventory re-exported from catalog for gen-k3d.clj.
package k3d

import "github.com/defn/other/kernel/catalog"

// Re-export cluster map from catalog (source of truth).
clusters: catalog.k3d_clusters
