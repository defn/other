@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/module/aws-account": {
		path: "kernel/module/aws-account"
		slug: "module--aws-account"
		kind: "interface"
		reads: []
		writes: []
		desc:        "account-level tofu module (IAM roles)"
		midas:       true
		stamping:    "generator"
		catalog_key: "aws_accounts"
	}
}
