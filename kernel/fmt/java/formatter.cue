@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "java"
	tool: "google-java-format"
	cmd: ["--replace"]
	extensions: [".java"]
	runtime: "jar"
}
