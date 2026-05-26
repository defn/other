@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

#Formatter: {
	name:    string // file type name (map key)
	tool:    string // mise tool name
	version: string // resolved from versions
	cmd: [...string] // command args (after tool binary)
	extensions: [...string] // file extensions this handles
	runtime:                *"native" | "jar"
}
