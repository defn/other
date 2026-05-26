@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// #ScriptingPolicy defines approved libraries for babashka scripts.
// Scripts may only require libraries on this list; all other
// dependencies must be accessed through the approved libraries.
#ScriptingPolicy: {
	approved_requires: [...string]
}
