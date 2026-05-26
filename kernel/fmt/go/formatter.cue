@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "go"
	tool: "gofmt"
	cmd: ["-w"]
	extensions: [".go"]
}
