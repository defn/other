@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #GmailBot defines a Gmail bot instance.
#GmailBot: {
	name:         string // brick name (lowercase, e.g., "lament")
	display_name: string // capitalized display name (e.g., "Lament")
	full_name:    string // full name (e.g., "Lament")
	path:         string // brick path (e.g., "bot/lament")
}
