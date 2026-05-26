@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "markdown"
	tool: "prettier"
	cmd: ["--write", "--prose-wrap", "preserve"]
	extensions: [".md"]
}
