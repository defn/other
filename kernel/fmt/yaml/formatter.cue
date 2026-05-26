@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "yaml"
	tool: "yq"
	cmd: ["-i", "."]
	extensions: [".yaml", ".yml"]
}
