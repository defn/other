@experiment(aliasv2,explicitopen,shortcircuit,try)

// k8s.cue -- k8s platform inventory re-exported from catalog for gen-k8s.clj.
package k8s

import "github.com/defn/other/kernel/catalog"

// Re-export platform map from catalog (source of truth).
platforms: catalog.k8s_platforms
