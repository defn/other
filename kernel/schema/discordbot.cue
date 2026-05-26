@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #DiscordBot defines a Discord bot instance.
#DiscordBot: {
	name:         string // brick name (lowercase, e.g., "feanor")
	display_name: string // capitalized display name (e.g., "Feanor")
	full_name:    string // full name (e.g., "Feanor")
	path:         string // brick path (e.g., "bot/feanor")
}
