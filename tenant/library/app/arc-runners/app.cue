@experiment(aliasv2,explicitopen,shortcircuit,try)

package app

// GitHub orgs to run runners for.
// Each org gets its own AutoscalingRunnerSet and ExternalSecret.
// Add orgs here to deploy runners for additional GitHub organizations.
//
// ## Secret provisioning
//
// Each org needs a GitHub fine-grained PAT stored in AWS Secrets Manager.
//
// 1. Create fine-grained PAT at https://github.com/settings/personal-access-tokens
//    - Resource owner: the GitHub org (e.g. "defn")
//    - Repository access: No repositories (none needed)
//    - Organization permissions:
//      - "Self-hosted runners" -> Read and Write
//      - "Administration" -> Read and Write (needed for registration token)
//    - No repository permissions required
//    - The token owner must be an org admin
//
// 2. Add to AWS Secrets Manager for each cluster:
//    aws secretsmanager get-secret-value \
//      --secret-id "defn/<cluster>-secrets" \
//      --query 'SecretString' --output text \
//      | jq --arg token "ghp_YOUR_TOKEN" \
//        '. + {"arc-github-token-<org>": $token}' \
//      | aws secretsmanager put-secret-value \
//          --secret-id "defn/<cluster>-secrets" \
//          --secret-string file:///dev/stdin
//
// 3. ESO syncs automatically (1h refresh), or force:
//    kubectl annotate externalsecret arc-github-secret-<org> \
//      -n arc-runners force-sync=$(date +%s) --overwrite
arc_orgs: [string]: {
	github_url:  string
	max_runners: *5 | number
}

arc_orgs: defn: {
	github_url:  "https://github.com/defn"
	max_runners: 5
}

// overlay.cue -- per-cluster, per-org runner resources.

_cluster_name:   string @tag(cluster_name)
_cluster_domain: string @tag(cluster_domain)
_dns_zone:       string @tag(dns_zone)

// Per-org ExternalSecrets for GitHub tokens
objects: ExternalSecret: {
	for org_name, _ in arc_orgs {
		"arc-github-secret-\(org_name)": {
			apiVersion: "external-secrets.io/v1"
			kind:       "ExternalSecret"
			metadata: {
				name:      "arc-github-secret-\(org_name)"
				namespace: "arc-runners"
			}
			spec: {
				refreshInterval: "1h"
				secretStoreRef: {
					name: "aws-secrets-manager"
					kind: "ClusterSecretStore"
				}
				target: name: "arc-github-secret-\(org_name)"
				data: [{
					secretKey: "github_token"
					remoteRef: {
						key:                "defn/\(_cluster_name)-secrets"
						property:           "arc-github-token-\(org_name)"
						conversionStrategy: "Default"
						decodingStrategy:   "None"
						metadataPolicy:     "None"
					}
				}]
			}
		}
	}
}

// Per-org runner resources: ServiceAccount, Role, RoleBinding, AutoscalingRunnerSet
objects: {
	for org_name, org in arc_orgs {
		let _prefix = "arc-runners-\(org_name)"

		ServiceAccount: "\(_prefix)-no-permission": {
			apiVersion: "v1"
			kind:       "ServiceAccount"
			metadata: {
				finalizers: ["actions.github.com/cleanup-protection"]
				labels: {
					"actions.github.com/scale-set-name":      _prefix
					"actions.github.com/scale-set-namespace": "arc-runners"
				}
				name:      "\(_prefix)-no-permission"
				namespace: "arc-runners"
			}
		}

		Role: "\(_prefix)-manager": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "Role"
			metadata: {
				finalizers: ["actions.github.com/cleanup-protection"]
				labels: {
					"actions.github.com/scale-set-name":      _prefix
					"actions.github.com/scale-set-namespace": "arc-runners"
				}
				name:      "\(_prefix)-manager"
				namespace: "arc-runners"
			}
			rules: [{
				apiGroups: [""]
				resources: ["pods"]
				verbs: ["create", "delete", "get"]
			}, {
				apiGroups: [""]
				resources: ["pods/status"]
				verbs: ["get"]
			}, {
				apiGroups: [""]
				resources: ["secrets"]
				verbs: ["create", "delete", "get", "list", "patch", "update"]
			}, {
				apiGroups: [""]
				resources: ["serviceaccounts"]
				verbs: ["create", "delete", "get", "list", "patch", "update"]
			}, {
				apiGroups: ["rbac.authorization.k8s.io"]
				resources: ["rolebindings"]
				verbs: ["create", "delete", "get", "patch", "update"]
			}, {
				apiGroups: ["rbac.authorization.k8s.io"]
				resources: ["roles"]
				verbs: ["create", "delete", "get", "patch", "update"]
			}]
		}

		RoleBinding: "\(_prefix)-manager": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "RoleBinding"
			metadata: {
				finalizers: ["actions.github.com/cleanup-protection"]
				labels: {
					"actions.github.com/scale-set-name":      _prefix
					"actions.github.com/scale-set-namespace": "arc-runners"
				}
				name:      "\(_prefix)-manager"
				namespace: "arc-runners"
			}
			roleRef: {
				apiGroup: "rbac.authorization.k8s.io"
				kind:     "Role"
				name:     "\(_prefix)-manager"
			}
			subjects: [{
				kind:      "ServiceAccount"
				name:      "arc-gha-rs-controller"
				namespace: "arc-systems"
			}]
		}

		AutoscalingRunnerSet: "\(_prefix)": {
			apiVersion: "actions.github.com/v1alpha1"
			kind:       "AutoscalingRunnerSet"
			metadata: {
				annotations: {
					"actions.github.com/cleanup-manager-role-binding":               "\(_prefix)-manager"
					"actions.github.com/cleanup-manager-role-name":                  "\(_prefix)-manager"
					"actions.github.com/cleanup-no-permission-service-account-name": "\(_prefix)-no-permission"
				}
				labels: {
					"actions.github.com/scale-set-name":      _prefix
					"actions.github.com/scale-set-namespace": "arc-runners"
					"app.kubernetes.io/version":              "0.14.0"
					"app.kubernetes.io/part-of":              "gha-rs"
					"app.kubernetes.io/component":            "autoscaling-runner-set"
				}
				name:      _prefix
				namespace: "arc-runners"
			}
			spec: {
				githubConfigSecret: "arc-github-secret-\(org_name)"
				githubConfigUrl:    org.github_url
				maxRunners:         org.max_runners
				minRunners:         0
				template: spec: {
					containers: [{
						command: ["/home/runner/run.sh"]
						image: "host.k3d.internal:5000/mirror/ghcr.io/actions/actions-runner:2.323.0"
						name:  "runner"
					}]
					restartPolicy:      "Never"
					serviceAccountName: "\(_prefix)-no-permission"
				}
			}
		}
	}
}
