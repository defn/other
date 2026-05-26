// Language version is patched by Bazel genrule //cue.mod:module_cue_gen from schema/versions.cue.
// Do not edit the version by hand. Run: bazelisk run //cue.mod:module_cue_sync

@experiment(aliasv2,explicitopen,shortcircuit,try)

module: "github.com/defn/other"
language: {
	version: "v0.17.0"
}
