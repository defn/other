@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

// Tags passed by the per-cluster genrule but unused by this app.
_account_id:       string @tag(account_id)
_irsa_role_prefix: string @tag(irsa_role_prefix)

// All per-org runner resources are generated in app.cue.
// Namespace is managed by capsule-tenants.
// This empty objects map satisfies the raw app genrule contract.
objects: {}
