@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #SlackBot defines a Slack bot instance.
#SlackBot: {
	name:         string // brick name (lowercase, e.g., "dixie")
	display_name: string // capitalized display name (e.g., "Dixie")
	full_name:    string // full character name (e.g., "Dixie Flatline")
	path:         string // brick path (e.g., "bot/dixie")
}
