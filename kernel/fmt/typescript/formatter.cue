@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "typescript"
	tool: "biome"
	cmd: ["format", "--write"]
	extensions: [".ts"]
}
