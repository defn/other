@experiment(aliasv2,explicitopen,shortcircuit,try)

package fmt

formatter: {
	name: "clojure"
	tool: "cljstyle"
	cmd: ["fix"]
	extensions: [".clj"]
	runtime: "jar"
}
