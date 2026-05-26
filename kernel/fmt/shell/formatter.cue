@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "shell"
	tool: "shfmt"
	cmd: ["-w"]
	extensions: [".sh"]
}
