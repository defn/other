@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "packer"
	tool: "packer"
	cmd: ["fmt"]
	extensions: [".pkr.hcl"]
}
