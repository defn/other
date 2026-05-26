@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "json"
	tool: "biome"
	cmd: ["format", "--write"]
	extensions: [".json"]
}
