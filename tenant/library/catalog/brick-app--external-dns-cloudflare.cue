@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/external-dns-cloudflare": {
		path:       "tenant/library/app/external-dns-cloudflare"
		slug:       "app--external-dns-cloudflare"
		kind:       "component"
		desc:       "ExternalDNS Cloudflare provider for DNSEndpoint CRs"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
