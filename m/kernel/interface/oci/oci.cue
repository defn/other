@experiment(aliasv2,explicitopen,shortcircuit,try)

// oci.cue -- OCI image inventory re-exported from catalog.
package oci

import "github.com/defn/other/kernel/catalog"

// Re-export OCI images from catalog (source of truth).
oci_images: catalog.oci_images
