@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "github.com/defn/other/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"tenant/library/app/oauth2-proxy": {
		path:       "tenant/library/app/oauth2-proxy"
		slug:       "app--oauth2-proxy"
		kind:       "component"
		desc:       "OAuth2 reverse proxy for SSO"
		implements: "kernel/interface/app"
		stamp_type: "gen"
		reads: []
		writes: []
	}
}
