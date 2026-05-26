@experiment(aliasv2,explicitopen,shortcircuit,try)

// irsa_patch.cue -- generates per-cluster kustomize patches for IRSA.
// Evaluated with cluster tags to produce concrete patch YAML.
package k8s

_cluster_name:     string @tag(cluster_name)
_account_id:       string @tag(account_id)
_irsa_role_prefix: string @tag(irsa_role_prefix)
_irsa_region:      string @tag(irsa_region)
_workload:         string @tag(workload)
_deployment_name:  string @tag(deployment_name)
_container_name:   string @tag(container_name)
_namespace:        string @tag(namespace)
_sa_name:          string @tag(sa_name)

_role_arn: "arn:aws:iam::\(_account_id):role/\(_irsa_role_prefix)\(_cluster_name)-\(_workload)"

// Strategic merge patch for the Deployment
irsa_patch: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		name:      _deployment_name
		namespace: _namespace
	}
	spec: template: spec: {
		containers: [{
			name: _container_name
			env: [{
				name:  "AWS_REGION"
				value: _irsa_region
			}, {
				name:  "AWS_ROLE_ARN"
				value: _role_arn
			}, {
				name:  "AWS_WEB_IDENTITY_TOKEN_FILE"
				value: "/var/run/secrets/irsa/token"
			}]
			volumeMounts: [{
				name:      "irsa-token"
				mountPath: "/var/run/secrets/irsa"
				readOnly:  true
			}]
		}]
		volumes: [{
			name: "irsa-token"
			projected: sources: [{
				serviceAccountToken: {
					audience:          "sts.amazonaws.com"
					expirationSeconds: 86400
					path:              "token"
				}
			}]
		}]
	}
}

// Strategic merge patch for the ServiceAccount annotation
sa_patch: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		name:      _sa_name
		namespace: _namespace
		annotations: "eks.amazonaws.com/role-arn": _role_arn
	}
}
