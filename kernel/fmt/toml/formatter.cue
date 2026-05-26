@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "toml"
	tool: "taplo"
	cmd: ["format"]
	extensions: [".toml"]
}
