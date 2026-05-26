@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #MirrorImage defines a container image tracked in the mirror catalog.
//
// The catalog is the source of truth for all external container images
// used by apps in the platform. Each entry tracks the upstream source
// with its tag and resolved digest (lockfile).
//
// Fields:
//   source: fully-qualified upstream image (e.g. "ghcr.io/coder/coder")
//   tag:    version tag (e.g. "v2.30.1")
//   digest: resolved sha256 digest (empty string until locked)
#MirrorImage: {
	source: string
	tag:    string
	digest: string | *""
}
