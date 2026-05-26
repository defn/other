@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #OciImage defines an external OCI image pulled by crane.
#OciImage: {
	name:   string // logical name (map key)
	source: string // upstream registry/repo:tag
	digest: string // pinned sha256 digest
	tag:    string // local tag (defn.dev/external/...)
}
