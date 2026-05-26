@experiment(aliasv2,explicitopen,shortcircuit,try)

// Package schema -- mise.toml model.
//
// This file defines the structure of m/mise.toml so it can be generated
// from the version data in versions.cue.  The generator script
// (gen-mise-toml.clj) evaluates mise_tools and emits TOML.
package schema

// #MiseToolEntry is one line (or block) in the [tools] section.
#MiseToolEntry: {
	id:      string // mise tool identifier
	version: string // version string
	opts?: {[string]: string} // extra TOML inline-table fields
	group?:   string // section header comment (emitted before entry)
	comment?: string // inline comment (appended after entry)
	notes?: [...string] // extra comment lines before this entry
}

// mise_tools is the ordered list of tool entries for m/mise.toml [tools].
// Empty -- all tools are now global in root/.config/mise/config.toml.
mise_tools: [...#MiseToolEntry] & []

// root_mise_tools is the ordered list of tool entries for root/.config/mise/config.toml.
// All tools are global so they are available everywhere.
root_mise_tools: [...#MiseToolEntry] & [
	// Shell prompt
	{
		id:      "starship"
		version: versions.starship.version
		group:   "Shell prompt"
	},

	// Bazel
	{
		id:      "bazelisk"
		version: versions.bazelisk.version
		group:   "Bazel -- managed via bazelisk"
		notes: ["Actual Bazel version is in .bazelversion (\(versions.bazel.version))"]
	},

	// Go
	{
		id:      "go"
		version: versions.go.version
		group:   "Go toolchain"
	},

	// CUE
	{
		id:      "cue"
		version: versions.cue.version
		group:   "CUE language toolchain"
	},

	// Python
	{
		id:      "python"
		version: versions.python.version
		group:   "Python toolchain"
		comment: versions.python.constraint
	},

	// Scripting
	{
		id:      "babashka"
		version: versions.babashka.version
		group:   "Scripting"
		comment: "babashka (bb) for all scripts via bbs wrapper"
	},
	{
		id:      "go:github.com/traefik/yaegi/cmd/yaegi"
		version: versions.yaegi.version
		comment: "Go interpreter for scripts; use bin/yae shebang wrapper"
	},

	// JavaScript / Node.js
	{
		id:      "node"
		version: versions.node.version
		group:   "JavaScript/Node.js"
		comment: versions.node.constraint
	},
	{
		id:      "pnpm"
		version: versions.pnpm.version
		comment: versions.pnpm.constraint
	},

	// Java
	{
		id:      "java"
		version: versions.java.version
		group:   "Java (GraalVM CE -- includes native-image for AOT compilation)"
	},
	{id: "maven", version: versions.maven.version},

	// Formatters
	{
		id:      "biome"
		version: versions.biome.version
		group:   "Formatters"
	},
	{id: "buildifier", version: versions.buildifier.version},
	{
		id:      "ruff"
		version: versions.ruff.version
		notes: ["cljstyle: managed as JAR via m/bin/cljstyle (no linux-arm64 native binary)"]
	},
	{id: "github:mvdan/sh", version: versions.shfmt.version},
	{id: "dprint", version: versions.dprint.version},
	{id: "opentofu", version: versions.opentofu.version},
	{id: "packer", version: versions.packer.version},
	{id: "prettier", version: versions.prettier.version},
	{id: "taplo", version: versions.taplo.version},

	// Package managers
	{
		id:      "uv"
		version: versions.uv.version
		group:   "Package managers"
		comment: versions.uv.constraint
	},
	{id: "pipx", version: versions.pipx.version},

	// CLI tools
	{
		id:      "aws"
		version: versions.aws.version
		group:   "CLI tools"
	},
	{
		id:      "ansible"
		version: versions.ansible.version
	},
	{id: "coder", version: versions.coder.version},
	{id: "gh", version: versions.gh.version},
	{id: "jq", version: versions.jq.version},
	{id: "k3d", version: versions.k3d.version},
	{id: "yq", version: versions.yq.version},
	{id: "aqua:tailscale/tailscale", version: versions.tailscale_cli.version},

	// Services
	{
		id:      "github:coder/code-server"
		version: versions["code-server"].version
		group:   "Services"
		opts: {bin_path: "bin", extract_all: "true"}
	},

	// Container tools
	{
		id:      "github:google/go-containerregistry"
		version: versions.crane.version
		group:   "Container tools"
		comment: versions.crane.constraint
		opts: {exe: "crane"}
	},
	{
		id:      "github:regclient/regclient"
		version: versions.regctl.version
		comment: versions.regctl.constraint
		opts: {exe: "regctl"}
	},
	{id: "trufflehog", version: versions.trufflehog.version},

	// Kubernetes / GitOps
	{
		id:      "argocd"
		version: versions.argocd.version
		group:   "Kubernetes / GitOps"
	},
	{id: "helm", version: versions.helm.version},
	{
		id:      "github:rancher/k3k"
		version: versions.k3k.version
		opts: {matching: "k3kcli"}
		// ubi installs raw-binary github assets under the asset's
		// filename (k3kcli), not the repo basename, so `which k3k`
		// doesn't resolve directly. m/bin/k3k is a thin shim that
		// execs `mise x github:rancher/k3k -- k3kcli "$@"` (AIDR-00129
		// Option C); operators can type `k3k` as if it were on PATH.
		comment: "k3kcli (raw-binary github release; user-facing verb `k3k` provided by m/bin/k3k shim)"
	},
	{id: "kube-controller-tools", version: versions.kube_controller_tools.version},
	{id: "kustomize", version: versions.kustomize.version},

	// Interactive CLI tools
	{
		id:      "bat"
		version: versions.bat.version
		group:   "Interactive CLI tools"
	},
	{id: "difftastic", version: versions.difftastic.version},
	{id: "fzf", version: versions.fzf.version},
	{id: "glow", version: versions.glow.version},

	// AI tools
	{
		id:      "npm:@anthropic-ai/claude-code"
		version: versions["claude-code"].version
		group:   "AI tools"
	},
	{
		id:      "npm:@zed-industries/claude-agent-acp"
		version: versions["claude-agent-acp"].version
		notes: ["ACP bridge for `defn dispatch --acp-prompt`"]
	},
	{id: "opencode", version: versions.opencode.version},

	// Protobuf tools
	{
		id:      "buf"
		version: versions.buf.version
		group:   "Protobuf tools"
	},
	{id: "protoc", version: versions.protoc.version},

	// Job queue tools
	{
		id:      "go:github.com/riverqueue/river/cmd/river"
		version: versions.river.version
		group:   "Job queue tools"
	},

	// CI tools
	{
		id:      "github:buildkite/cli"
		version: versions.buildkite_cli.version
		group:   "CI tools"
	},
	{
		id:      "github:buildkite/agent"
		version: versions.buildkite_agent.version
	},
	{
		id:      "git-lfs"
		version: versions.git_lfs.version
	},
	{
		id:      "aqua:jdx/pitchfork"
		version: versions.pitchfork.version
		group:   "CI tools"
	},
	{
		id:      "github:always-further/nono"
		version: versions.nono.version
	},
]
