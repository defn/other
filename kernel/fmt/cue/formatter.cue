@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "cue"
	tool: "cue"
	cmd: ["fmt"]
	extensions: [".cue"]
}
