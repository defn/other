@experiment(aliasv2,explicitopen,shortcircuit,try)

// env.cue -- environment inventory re-exported from catalog for gen-env.clj.
package env

import "github.com/defn/other/kernel/catalog"

// Re-export environment map from catalog (source of truth).
environments: catalog.environments

// Re-export platform map for resolving apps.
k8s_platforms: catalog.k8s_platforms

// Re-export chart versions for targetRevision in Application CRs.
chart_versions: catalog.chart_versions
