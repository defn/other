@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "bazel"
	tool: "buildifier"
	cmd: []
	extensions: [".bazel", ".bzl"]
}
