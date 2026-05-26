@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #Domain defines a registered domain name.
#Domain: {
	name:  string // fully qualified domain name
	desc?: string
}
