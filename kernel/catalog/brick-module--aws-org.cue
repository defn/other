@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/module/aws-org": {
		path: "kernel/module/aws-org"
		slug: "module--aws-org"
		kind: "interface"
		reads: []
		writes: []
		desc:        "org-level tofu module (organizations, SSO, child accounts)"
		midas:       true
		stamping:    "generator"
		catalog_key: "aws_orgs"
	}
}
