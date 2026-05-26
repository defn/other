@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

// Tags passed by the per-cluster genrule but unused by this app.
_account_id:       string @tag(account_id)
_irsa_role_prefix: string @tag(irsa_role_prefix)

// All objects are defined in app.cue.
// This empty objects map satisfies the raw app genrule contract.
objects: {}
