@experiment(aliasv2,explicitopen,shortcircuit,try)

// image.cue -- container image inventory re-exported from catalog.
package image

import "github.com/defn/other/kernel/catalog"

// Re-export container images from catalog (source of truth).
container_images: catalog.container_images
