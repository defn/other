@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: versionsbzl generator.
//
// Traceability:
//   Go source:   go/lib/gen/versionsbzl/versionsbzl.go
//   Reads:       schema.versions (every entry)
//
// Why these files exist: Bazel genrules that invoke tools via mise
// need the tool version as a Starlark constant (e.g. `CUE_VERSION`
// in a .bzl load). versionsbzl iterates every entry in schema.versions
// and writes gen-versions/<tool>.bzl containing the version plus
// optional chart_version and chart_sha256.
//
// The tool list is kept as a sorted _tools list here so a new
// version entry only needs adding once. The vet will fail with a
// helpful orphan message if someone adds a tool in schema.versions
// without updating this contract (or vice versa).
//
// gen-versions/BUILD.bazel is hand-written (a single glob-based
// Starlark file that fmt_tests and tags every .bzl). It's in
// spec/manual-files.cue, NOT claimed here.
//
// See AIDR-00062.

package contracts

_versionsbzl: tools: [
	"ack_iam",
	"ansible",
	"arc",
	"arc_runners",
	"argo_rollouts",
	"argocd",
	"aspect_bazel_lib",
	"aspect_rules_js",
	"aspect_rules_ts",
	"aws",
	"babashka",
	"bat",
	"bazel",
	"bazel_skylib",
	"bazelisk",
	"biome",
	"buf",
	"buildbuddy",
	"buildifier",
	"buildkite_agent",
	"buildkite_cli",
	"capsule",
	"cert_manager",
	"claude-agent-acp",
	"claude-code",
	"cljstyle",
	"cloudnative_pg",
	"code-server",
	"coder",
	"crane",
	"cue",
	"cue_language",
	"defn",
	"delta",
	"dex",
	"difftastic",
	"dprint",
	"external_dns",
	"external_secrets",
	"fzf",
	"gazelle",
	"gh",
	"git_lfs",
	"glow",
	"go",
	"goldilocks",
	"google-java-format",
	"helm",
	"java",
	"jq",
	"k3d",
	"k3k",
	"k3s",
	"k3s_b",
	"k3s_c",
	"k8s_a",
	"k8s_b",
	"k8s_c",
	"karpenter",
	"keda",
	"kruise",
	"kube_controller_tools",
	"kubectl",
	"kustomize",
	"kyverno",
	"linkerd",
	"linkerd_crds",
	"maven",
	"metrics_server",
	"node",
	"nono",
	"oauth2_proxy",
	"opencode",
	"opentofu",
	"packer",
	"pipx",
	"pitchfork",
	"platforms",
	"pnpm",
	"prettier",
	"protobuf",
	"protoc",
	"python",
	"redis_operator",
	"regctl",
	"reloader",
	"river",
	"ruff",
	"rules_cc",
	"rules_go",
	"rules_img",
	"rules_java",
	"rules_nodejs",
	"rules_oci",
	"rules_pkg",
	"rules_proto",
	"rules_proto_grpc",
	"rules_proto_grpc_go",
	"rules_python",
	"rules_shell",
	"rules_uv",
	"shfmt",
	"starship",
	"tailscale",
	"tailscale_cli",
	"taplo",
	"temporal",
	"toolchains_protoc",
	"topolvm",
	"traefik",
	"trufflehog",
	"trust_manager",
	"typescript",
	"uv",
	"vcluster",
	"vpa",
	"yaegi",
	"yq",
]

generators: versionsbzl: {
	generator: "versionsbzl"
	source:    "tenant/library/go/lib/gen/versionsbzl"
	reason:    "emits one gen-versions/<tool>.bzl per entry in schema.versions so Bazel genrules can load pinned versions as Starlark constants"
	read_from: {
		schema: ["versions"]
	}
	related_aidr: [62]
	paths: [
		for t in _versionsbzl.tools {"kernel/gen-versions/\(t).bzl"},
	]
}
