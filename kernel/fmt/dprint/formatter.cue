@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "dprint"
	tool: "dprint"
	cmd: ["fmt"]
	extensions: ["Dockerfile"]
}
