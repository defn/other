@experiment(aliasv2,explicitopen,shortcircuit,try)

// brick-_root.cue -- the monorepo root branch. Composes every
// kernel-side block by name (the kernel set is fixed and small)
// plus auto-discovers tenant branches via comprehension over the
// brick catalog: any brick with kind=branch and a tenant/-prefixed
// path registers automatically. No tenant names hard-coded; this
// is part of the kernel/tenant decoupling per AIDR-00071.
//
// .mise/tasks subdirs are NOT listed here -- each brick that owns
// one declares it implicitly via the .mise/tasks claim convention
// (kernel/spec/convention-contracts.cue), and the emitted mise.toml
// `task_config.includes` list is derived from a filesystem walk
// (gen/misetoml).

package catalog

import (
	"list"
	"strings"

	"github.com/defn/other/kernel/schema"
)

bricks: [string]: schema.#Brick

bricks: {
	"": {
		path: ""
		kind: "branch"
		reads: []
		desc: "monorepo root composing all top-level blocks"
		composes: list.Sort(list.Concat([
			[
				".devcontainer",
				"aidr",
				"bin",
				"cue.mod",
				"kernel/catalog",
				"kernel/doc",
				"kernel/fmt",
				"kernel/gen-versions",
				"kernel/gross",
				"kernel/helpers",
				"kernel/image",
				"kernel/interface/app",
				"kernel/interface/aws",
				"kernel/interface/discord-bot",
				"kernel/interface/env",
				"kernel/interface/fmt",
				"kernel/interface/gmail-bot",
				"kernel/interface/go-cmd",
				"kernel/interface/go-cmd-cue",
				"kernel/interface/go-cmd-parent",
				"kernel/interface/go-lib",
				"kernel/interface/image",
				"kernel/interface/k3d",
				"kernel/interface/k8s",
				"kernel/interface/matrix-bot",
				"kernel/interface/oci",
				"kernel/interface/slack-bot",
				"kernel/lib",
				"kernel/manifest",
				"kernel/module",
				"kernel/oci",
				"kernel/schema",
				"kernel/spec",
				"root",
				"root/.aws",
				"root/.config",
			],
			// Auto-discovered: every top-level tenant block at depth 3
			// (tenant/<t>/<dir>). Includes branches and components alike --
			// the historical hand-list mixed both. Deeper paths are
			// composed by the dir-specific branches, not by _root.
			[for p, _ in bricks
				if strings.HasPrefix(p, "tenant/")
				if len(strings.Split(p, "/")) == 3 {p}],
		]), list.Ascending)
	}
}
