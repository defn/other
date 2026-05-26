@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"kernel/spec": {
		path: "kernel/spec"
		slug: "spec"
		kind: "component"
		reads: []
		writes: []
		desc: "lattice + schema vet, contracts vet, fork-readiness checks"
	}
}
