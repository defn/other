@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #ContainerImage defines a container image built from a Dockerfile.
#ContainerImage: {
	name:       string // image name (map key, also dir name under image/)
	image_tag:  string // full image tag
	dockerfile: string // Dockerfile path relative to image/<name>/
	base:       string // FROM image
}
