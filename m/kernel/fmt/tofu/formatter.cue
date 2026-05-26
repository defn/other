@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "tofu"
	tool: "opentofu"
	cmd: ["fmt"]
	extensions: [".tf", ".tfvars"]
}
