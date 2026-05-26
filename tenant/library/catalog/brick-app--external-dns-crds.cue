@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/external-dns-crds": {
		path:       "tenant/library/app/external-dns-crds"
		slug:       "app--external-dns-crds"
		kind:       "component"
		desc:       "ExternalDNS DNSEndpoint CRD"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
