@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/module/aws-irsa": {
		path: "kernel/module/aws-irsa"
		slug: "module--aws-irsa"
		kind: "interface"
		reads: []
		writes: []
		desc: "per-k3d-run IRSA OIDC infrastructure (S3 + OIDC provider)"
	}
}
