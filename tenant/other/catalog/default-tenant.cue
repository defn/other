@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

// Pin default_tenant to this fork's leaf so gen stamps
// tenant/other/... rather than the upstream default tenant/defn.
default_tenant: "other"
