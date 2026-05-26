@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

// Namespaces are managed exclusively by capsule-tenants. Any raw app
// that tries to declare a Namespace in its gen-app.cue will conflict
// with this pattern constraint at `cue export` time, producing a hard
// CUE error before YAML is ever rendered. This supersedes the earlier
// sh_test-based check (interface/app/no-namespaces-test.clj) for raw
// apps, where the policy is enforced at the CUE layer.
objects: Namespace: [string]: _|_
