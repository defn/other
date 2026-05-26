@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "python"
	tool: "ruff"
	cmd: ["format"]
	extensions: [".py"]
}
