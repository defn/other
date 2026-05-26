@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #MatrixBot defines a Matrix bot instance.
#MatrixBot: {
	name:         string // brick name (lowercase, e.g., "turgon")
	display_name: string // capitalized display name (e.g., "Turgon")
	full_name:    string // full name (e.g., "Turgon")
	path:         string // brick path (e.g., "bot/turgon")
}
