@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #K3dCluster defines a k3d local Kubernetes cluster instance.
#K3dCluster: {
	cluster_name:       string                            // k3d cluster name (map key)
	dir:                string                            // subdirectory under k3d/
	k3s_version:        string                            // k3s semver
	api_port:           string                            // kubeAPI host port (must be unique)
	version_var:        string                            // Bazel tools.bzl variable name
	path:               string                            // workspace-relative path
	irsa_region:        *"us-east-1" | string             // AWS region for IRSA
	irsa_role_prefix:   *"defn-tmp-" | string             // prefix for IRSA IAM role names
	cluster_domain?:    string                            // base domain (e.g. a.d3fn.com)
	dns_zone?:          string                            // Cloudflare DNS zone (e.g. d3fn.com)
	dns01_nameservers?: *"1.1.1.1:53,8.8.8.8:53" | string // recursive nameservers for DNS01 challenge
	// acme_endpoint selects the Let's Encrypt directory used for the
	// per-cluster wildcard cert. "prod" issues real, browser-trusted
	// certs but is rate-limited (5 certs / 168h per identifier set);
	// "staging" issues untrusted certs with much higher limits, suited
	// for dev/test clusters. Default is "prod" so production clusters
	// don't need to set it explicitly.
	acme_endpoint?: *"prod" | "staging"
}
