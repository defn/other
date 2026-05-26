@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #TelegramBot defines a telegrambot instance.
#TelegramBot: {
	name:         string // brick name (lowercase)
	display_name: string // capitalized display name
	full_name:    string // full name
	path:         string // brick path
}
