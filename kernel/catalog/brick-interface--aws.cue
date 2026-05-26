@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/interface/aws": {
		path: "kernel/interface/aws"
		slug: "interface--aws"
		kind: "interface"
		reads: []
		writes: []
		desc:        "AWS org/account definition contract"
		midas:       true
		stamping:    "generator"
		catalog_key: "aws_orgs"
	}
}
