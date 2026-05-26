@experiment(aliasv2,explicitopen,shortcircuit,try)

// Package schema defines tool versions and their sync relationships.
//
// This is the single source of truth for all pinned versions. When
// upgrading a tool, update the version here and run `mise run gen`.
//
// Generated/patched files (mise.toml, gen-versions.bzl, package.json,
// MODULE.bazel) are NOT listed as sync targets -- they are built from
// this schema automatically. Only manually-maintained files appear
// in sync.
//
// Pinning policies:
//   - All versions pinned (no floating tags).
//   - Node.js must be LTS (even-numbered).
//   - pnpm version must sync with package.json `packageManager` field.
//   - uv version pinned to match `rules_uv` bundled version.
//   - TypeScript must be exact version (no semver range).
package schema

import (
	"strings"
	"strconv"
)

// _minorOf extracts the minor version number from a semver string.
#MinorOf: {
	_v:     string
	_parts: strings.Split(_v, ".")
	out:    strconv.Atoi(_parts[1])
}

// #SyncTarget describes where a version string appears.
#SyncTarget: {
	file:    string // path relative to m/
	pattern: string // how the version appears in the file
	note?:   string // optional constraint or caveat
}

// #ToolVersion defines a versioned tool and its sync chain.
#ToolVersion: {
	version: string // the canonical version string
	sync: [...#SyncTarget] // files that must contain this version
	constraint?:           string // e.g. "LTS only", "must match rules_uv bundled"
	chart_version?:        string // helm chart version (when tool has a chart)
	chart_sha256?:         string // sha256 checksum of vendored chart tarball
	chart_url?:            string // upstream chart source for inspection
}

// All versioned tools -- toolchains, formatters, CLI tools, and Bazel modules.
versions: {
	// =========================================================================
	// Monorepo
	// =========================================================================

	defn: #ToolVersion & {
		version: "0.0.1"
		sync: []
	}

	// =========================================================================
	// Language toolchains
	// =========================================================================

	go: #ToolVersion & {
		version: "1.26.3"
		sync: []
	}

	python: #ToolVersion & {
		version:    "3.14.2"
		constraint: "FROZEN at 3.14.2: rules_python 2.0.2 supports 3.14.4, but mise 2026.3.9 mis-installs it (freethreaded-stripped asset, missing lib/). Unfreeze in sync-module-versions.clj once mise is fixed. See ~/TODO.md."
		sync: []
	}

	node: #ToolVersion & {
		version:    "24.14.1"
		constraint: "LTS only (even-numbered); must be available in rules_nodejs for linux_arm64"
		sync: []
	}

	pnpm: #ToolVersion & {
		version:    "10.33.2"
		constraint: "must sync with package.json packageManager or pnpm reinstalls endlessly"
		sync: []
	}

	typescript: #ToolVersion & {
		version:    "6.0.2"
		constraint: "exact version only (no semver range); must match MODULE.bazel"
		sync: []
	}

	cue: #ToolVersion & {
		version: "0.17.0-alpha.1"
		sync: []
	}

	cue_language: #ToolVersion & {
		version:    "0.17.0"
		constraint: "CUE language version in cue.mod/module.cue (v prefix); may differ from tool version"
		sync: []
	}

	java: #ToolVersion & {
		version:    "graalvm-community-25.0.2"
		constraint: "max JDK version from rules_java 9.6.1 (graalvm-community distribution)"
		sync: []
	}

	maven: #ToolVersion & {
		version: "3.9.16"
		sync: []
	}

	uv: #ToolVersion & {
		version:    "0.8.12"
		constraint: "pinned to match rules_uv 0.89.2 bundled version"
		sync: []
	}

	bazel: #ToolVersion & {
		version: "9.1.0"
		sync: []
	}

	bazelisk: #ToolVersion & {
		version: "1.29.0"
		sync: []
	}

	crane: #ToolVersion & {
		version:    "v0.18.0"
		constraint: "max version supported by rules_oci 2.3.0"
		sync: []
	}

	regctl: #ToolVersion & {
		version:    "v0.8.0"
		constraint: "max version supported by rules_oci 2.3.0"
		sync: []
	}

	// =========================================================================
	// Formatters
	// =========================================================================

	biome: #ToolVersion & {
		version: "2.4.15"
		sync: []
	}

	buildifier: #ToolVersion & {
		version: "8.5.1"
		sync: []
	}

	cljstyle: #ToolVersion & {
		version:    "0.17.642"
		constraint: "JAR-based; no linux-arm64 native binary"
		sync: []
	}

	"google-java-format": #ToolVersion & {
		version:    "1.35.0"
		constraint: "JAR-based formatter"
		sync: []
	}

	prettier: #ToolVersion & {
		version: "3.8.3"
		sync: []
	}

	ruff: #ToolVersion & {
		version: "0.15.14"
		sync: []
	}

	shfmt: #ToolVersion & {
		version: "3.13.1"
		sync: []
	}

	taplo: #ToolVersion & {
		version: "0.10.0"
		sync: []
	}

	dprint: #ToolVersion & {
		version:    "0.54.0"
		constraint: "WASM plugin-based formatter; Dockerfile plugin loaded from dprint.json"
		sync: []
	}

	opentofu: #ToolVersion & {
		version: "1.12.0"
		sync: []
	}

	packer: #ToolVersion & {
		version: "1.15.3"
		sync: []
	}

	yq: #ToolVersion & {
		version: "4.53.2"
		sync: []
	}

	// =========================================================================
	// Scripting
	// =========================================================================

	babashka: #ToolVersion & {
		version: "1.12.218"
		sync: []
	}

	yaegi: #ToolVersion & {
		version:    "0.16.1"
		constraint: "Go interpreter for scripting; use bin/yae as shebang wrapper"
		sync: []
	}

	// =========================================================================
	// Package managers (non-language)
	// =========================================================================

	pipx: #ToolVersion & {
		version: "1.12.0"
		sync: []
	}

	// =========================================================================
	// CLI tools
	// =========================================================================

	aws: #ToolVersion & {
		version: "2.34.53"
		sync: []
	}

	ansible: #ToolVersion & {
		version: "13.7.0"
		sync: []
	}

	coder: #ToolVersion & {
		version:       "2.33.6"
		chart_version: "2.33.6"
		chart_sha256:  "62be09c1eee4e5323fef4360138a2d6a2a8d52e8bfa9a88dad2a9438cf35e2cb"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/coder-v2/coder"
		sync: []
	}

	gh: #ToolVersion & {
		version: "2.92.0"
		sync: []
	}

	jq: #ToolVersion & {
		version: "1.8.1"
		sync: []
	}

	k3d: #ToolVersion & {
		version: "5.8.3"
		sync: []
	}

	kube_controller_tools: #ToolVersion & {
		version:    "0.21.0"
		constraint: "provides controller-gen for CRD generation from Go API types"
		sync: []
	}

	// =========================================================================
	// Kubernetes / GitOps
	// =========================================================================

	ack_iam: #ToolVersion & {
		version:       "1.6.3"
		chart_version: "1.6.4"
		chart_sha256:  "b182c6acc495a9f5e6e039cde8295020a39583c06a1f34e8785bdde6b6ff40fd"
		chart_url:     "https://gallery.ecr.aws/aws-controllers-k8s/iam-chart"
		sync: []
	}

	arc: #ToolVersion & {
		version:       "0.14.2"
		chart_version: "0.14.2"
		chart_sha256:  "222763b7edbe57eabe626cda09bb58040ed9c70471d32aab650c8e6825a3d8e7"
		chart_url:     "https://github.com/actions/actions-runner-controller"
		sync: []
	}

	arc_runners: #ToolVersion & {
		version:       "0.14.0"
		chart_version: "0.14.1"
		chart_sha256:  "42964b5f9c64136c8ac1a13c678386c6820b7bf301c4fbbafd89e7b9ac9aaa55"
		chart_url:     "https://github.com/actions/actions-runner-controller"
		sync: []
	}

	argocd: #ToolVersion & {
		version:       "3.4.2"
		chart_version: "9.5.15"
		chart_sha256:  "95502bea856e2e1e9bfbb7a5ab90d309970b4ffd098ff3dadb99188350768b9e"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/argo/argo-cd"
		sync: []
	}

	argo_rollouts: #ToolVersion & {
		version:       "1.9.0"
		chart_version: "2.40.9"
		chart_sha256:  "9028af96514d3e7443b68c56ecf17beae279e73982ffd6ee33bfeb6c70d42f22"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/argo/argo-rollouts"
		sync: []
	}

	capsule: #ToolVersion & {
		version:       "0.12.4"
		chart_version: "0.12.4"
		chart_sha256:  "6a60a1a770fa6f03bc9d4d5ed9524b709c27015a27d1db328aab7bc942f49f7d"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/projectcapsule/capsule"
		sync: []
	}

	cloudnative_pg: #ToolVersion & {
		version:       "1.29.0"
		chart_version: "0.28.2"
		chart_sha256:  "43c8029e2c88527cfde8dd19d88fd120f67565f5788b213a37de43ee96f64e64"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/cloudnative-pg/cloudnative-pg"
		sync: []
	}

	buildbuddy: #ToolVersion & {
		version:       "2.271.0"
		chart_version: "0.0.409"
		chart_sha256:  "f23901ec1a6bf82b14001b56c5f75d4c5c23bf2ef1638b74fd4edbf7c156caf5"
		chart_url:     "https://helm.buildbuddy.io"
		sync: []
	}

	temporal: #ToolVersion & {
		version:       "1.30.3"
		chart_version: "1.2.0"
		chart_sha256:  "c3825bc35d79441309fec6c36f7be449a08d2556de1f7c43d60dd39f482bac4a"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/temporalio/temporal"
		sync: []
	}

	cert_manager: #ToolVersion & {
		version:       "1.20.2"
		chart_version: "1.20.2"
		chart_sha256:  "d2a50bd44a09d838c2576a8f3dfca1524597c7393cf8d82ab3ec8a465b9eeb79"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/cert-manager/cert-manager"
		sync: []
	}

	dex: #ToolVersion & {
		version:       "2.44.0"
		chart_version: "0.24.0"
		chart_sha256:  "24d486ac2182b919483a9840339997443793ce637e3f10d37ab3284eaa229d33"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/dex/dex"
		sync: []
	}

	external_dns: #ToolVersion & {
		version:       "0.20.0"
		chart_version: "1.21.1"
		chart_sha256:  "5dd033a4b872bf641860695705ee460031d0bc695f114bf8926fee6736814e19"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/external-dns/external-dns"
		sync: []
	}

	external_secrets: #ToolVersion & {
		version:       "2.4.0"
		chart_version: "2.5.0"
		chart_sha256:  "7f8cb50cd236cc0f8476b333119cb507a3becdc896fdb7ab16329e521911018f"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/external-secrets-operator/external-secrets"
		sync: []
	}

	helm: #ToolVersion & {
		version:    "4.2.0"
		constraint: "latest helm release. Decoupled from ArgoCD (2026-04-20) because we don't rely on argocd-server to render charts; plain helm/kustomize drive rendering."
		sync: []
	}

	kubectl: #ToolVersion & {
		version:    "1.36.1"
		constraint: "must match k3s stable channel version \(versions.k3s.version)"
		sync: []
	}

	k3s: #ToolVersion & {
		version:    "1.36.1"
		constraint: "k3s stable channel; determines kubectl version"
		sync: []
	}

	// Per-cluster k3s pins. Cluster letters (a/b/c) decouple identifiers
	// from version digits, so a version bump touches only the version
	// strings here -- no symbol renames or per-app dir shuffles.
	// Cluster a == k3s stable (shared by defn-a and boot-a).
	k3s_b: #ToolVersion & {
		version:    "1.35.5"
		constraint: "1 minor behind k3s stable; latest patch for 1.35"
		sync: []
	}

	k3s_c: #ToolVersion & {
		version:    "1.34.8"
		constraint: "2 minor behind k3s stable; latest patch for 1.34"
		sync: []
	}

	// Enforce k3s minor version gaps (a is stable, b is -1, c is -2)
	_k3s_minor: (#MinorOf & {_v: versions.k3s.version}).out
	_k3s_b_minor: (#MinorOf & {_v: versions.k3s_b.version}).out
	_k3s_c_minor: (#MinorOf & {_v: versions.k3s_c.version}).out
	_k3s_b_minor: _k3s_minor - 1
	_k3s_c_minor: _k3s_minor - 2

	// K8s API version aliases -- used by app_kustomize_versioned for
	// --helm-kube-version. Values track the per-cluster k3s versions above.
	k8s_a: #ToolVersion & {
		version:    versions.k3s.version
		constraint: "k8s API version alias for cluster a (k3s stable)"
		sync: []
	}

	k8s_b: #ToolVersion & {
		version:    versions.k3s_b.version
		constraint: "k8s API version alias for cluster b"
		sync: []
	}

	k8s_c: #ToolVersion & {
		version:    versions.k3s_c.version
		constraint: "k8s API version alias for cluster c"
		sync: []
	}

	kustomize: #ToolVersion & {
		version:    "5.8.1"
		constraint: "latest kustomize release. Decoupled from ArgoCD (2026-04-20) -- tracks kubernetes-sigs/kustomize releases directly."
		sync: []
	}

	goldilocks: #ToolVersion & {
		version:       "4.14.1"
		chart_version: "10.3.0"
		chart_sha256:  "e4f9cfb3b41236fe18c55878bf30b74653e7b09f76da9e32ec417c351d889f71"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/fairwinds-stable/goldilocks"
		sync: []
	}

	kyverno: #ToolVersion & {
		version:       "1.18.1"
		chart_version: "3.8.1"
		chart_sha256:  "a33f35b83b6991daf6a1b1cf995becbe369747fcd84411d5089d55a40ee4ae0d"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/kyverno/kyverno"
		sync: []
	}

	keda: #ToolVersion & {
		version:       "2.19.0"
		chart_version: "2.19.0"
		chart_sha256:  "6ee0edbb604577aaa2db07a4eecd836c69e1b1266f2db88a55010870faaad34b"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/kedacore/keda"
		sync: []
	}

	karpenter: #ToolVersion & {
		version:       "1.12.0"
		chart_version: "1.12.1"
		chart_sha256:  "3419ff1831b440068fb1a25dc1d4755c23e1b442e16baad3ebd2c6ad9a86fdaf"
		chart_url:     "https://gallery.ecr.aws/karpenter/karpenter"
		sync: []
	}

	linkerd: #ToolVersion & {
		version:       "2.14.10"
		chart_version: "1.16.11"
		chart_sha256:  "913e4425cf1ec4293ab3ccdf161b9e09669df2ba551a6fc195fedb455f989247"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/linkerd2/linkerd-control-plane"
		sync: []
	}

	linkerd_crds: #ToolVersion & {
		version:       "1.8.0"
		chart_version: "1.8.0"
		chart_sha256:  "516789ccd8116f5f7ddd69ad2368be6f3c26cb53eae94f3950061592c0074991"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/linkerd2/linkerd-crds"
		sync: []
	}

	oauth2_proxy: #ToolVersion & {
		version:       "7.15.2"
		chart_version: "10.6.0"
		chart_sha256:  "2c7f4af15a8f7778e86880c7d805a224ed55261bd34d3aafc9d9619c24b05bb4"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/oauth2-proxy/oauth2-proxy"
		sync: []
	}

	metrics_server: #ToolVersion & {
		version:       "0.8.0"
		chart_version: "3.13.0"
		chart_sha256:  "fb929902e3b7565663cdd1734f31d63735c932be1541a7228b5aeef6d2348a1f"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/metrics-server/metrics-server"
		sync: []
	}

	redis_operator: #ToolVersion & {
		version:       "0.24.0"
		chart_version: "0.24.0"
		chart_sha256:  "7d56503fcf2e37ecb945034d83b7425fd93bf9b6249d9c1110c732711efe93ec"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/ot-container-kit/redis-operator"
		sync: []
	}

	reloader: #ToolVersion & {
		version:       "1.4.17"
		chart_version: "2.2.12"
		chart_sha256:  "8f745b263099ed57bad737e1e719f05ebc9fc2582f4e7b179e08affe81ad3b45"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/stakater/reloader"
		sync: []
	}

	traefik: #ToolVersion & {
		version:       "3.6.13"
		chart_version: "40.2.0"
		chart_sha256:  "b73d0159fc1222cc9bdaefde80000a9bad2dfe81de4caed14b9509b3bf6c1df9"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/traefik/traefik"
		sync: []
	}

	vpa: #ToolVersion & {
		version:       "1.6.0"
		chart_version: "4.11.0"
		chart_sha256:  "6aa04bd1de7ba890ed64d37343d4af026c86ba55146599fa7fbd84b1a23b9390"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/fairwinds-stable/vpa"
		sync: []
	}

	tailscale: #ToolVersion & {
		version:       "1.98.3"
		chart_version: "1.98.3"
		chart_sha256:  "a7413eb0ce91581ff66fc71a17da0cf19a1a822ed7a84fb4b52786ceb17065a0"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/tailscale/tailscale-operator"
		sync: []
	}

	// Structurally decoupled from the tailscale-operator above (the operator's
	// appVersion tracks container-image releases, which can run ahead of the
	// CLI pkg). The mise aqua CLI tool downloads a per-platform pkg from
	// pkgs.tailscale.com, so it must pin a version with pkgs for BOTH macOS
	// (host) and linux (CI + the Linux platform target). 1.96.5 was pruned
	// upstream (pkgs.tailscale.com 404s, not in `mise ls-remote aqua:...`),
	// which defn/other CI surfaced -- a pinned-then-pruned version that the
	// host never re-downloaded (cached) so check-fork missed it (AIDR-00149).
	// Must have pkgs for BOTH macOS (host: Tailscale-<v>-macos.pkg) and linux
	// (CI: tailscale_<v>_amd64.tgz). tailscale prunes the two channels
	// INDEPENDENTLY and erratically: 1.96.5 lost its linux .tgz; 1.98.3/1.96.4
	// have linux but no macOS .pkg; 1.98.2 has BOTH (verified 2026-05-25) and
	// is the latest such. Re-check both URLs before bumping -- `mise ls-remote`
	// listing a version is necessary but NOT sufficient (it 200s on one
	// platform, 404s on the other). defn/other CI surfaced the 1.96.5 linux
	// prune the cached host had hidden (AIDR-00149).
	tailscale_cli: #ToolVersion & {
		version:    "1.98.2"
		constraint: "mise aqua CLI tool; pinned to a tailscale version with pkgs on every platform (macOS host + linux CI). Decoupled from tailscale-operator appVersion."
		sync: []
	}

	topolvm: #ToolVersion & {
		version:       "0.40.2"
		chart_version: "16.1.0"
		chart_sha256:  "c219ec2f01d8b8bb80fb6818182debd9e427ad6aeef78ef79e96fd126b66e286"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/topolvm/topolvm"
		sync: []
	}

	trust_manager: #ToolVersion & {
		version:       "0.22.1"
		chart_version: "0.22.1"
		chart_sha256:  "7fac0640b4c58424ca7589a91dfdc2f79a3cd490c0b2b5b8d4cfea2654e9133f"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/cert-manager/trust-manager"
		sync: []
	}

	k3k: #ToolVersion & {
		version:       "v1.1.0-rc6"
		chart_version: "1.1.0"
		chart_sha256:  "251653c68d9ba40e7726d728877198f96e915451b9fc8d7e0f6d036bb19882cd"
		chart_url:     "https://artifacthub.io/api/v1/packages/helm/k3k/k3k"
		sync: []
	}

	// =========================================================================
	// Services
	// =========================================================================

	"code-server": #ToolVersion & {
		version: "4.121.0"
		sync: []
	}

	// =========================================================================
	// Security
	// =========================================================================

	trufflehog: #ToolVersion & {
		version: "3.95.3"
		sync: []
	}

	// =========================================================================
	// Interactive CLI tools
	// =========================================================================

	starship: #ToolVersion & {
		version: "1.25.1"
		sync: []
	}

	bat: #ToolVersion & {
		version: "0.26.1"
		sync: []
	}

	difftastic: #ToolVersion & {
		version: "0.69.0"
		sync: []
	}

	fzf: #ToolVersion & {
		version: "0.73.1"
		sync: []
	}

	glow: #ToolVersion & {
		version: "2.1.2"
		sync: []
	}

	// =========================================================================
	// AI tools
	// =========================================================================

	"claude-code": #ToolVersion & {
		version: "2.1.150"
		sync: []
	}

	// ACP bridge: adapts Claude Code to the Agent Client Protocol
	// (github.com/coder/acp-go-sdk on the Go side). Required by
	// `defn dispatch --acp-prompt=...`. Pinned so the dispatcher
	// uses a known-good bridge instead of `npx -y ...@latest`.
	//
	// Naming: the package was @zed-industries/claude-code-acp
	// through 0.16.x; renamed to @zed-industries/claude-agent-acp
	// at 0.17.0 (2026-02-17) tracking the upstream "Claude Code
	// SDK" -> "Claude Agent SDK" rename. Same author, same
	// protocol, continuous version sequence. We track the new
	// name; the old one is no longer maintained.
	"claude-agent-acp": #ToolVersion & {
		version: "0.23.1"
		sync: []
	}

	opencode: #ToolVersion & {
		version: "1.15.10"
		sync: []
	}

	pitchfork: #ToolVersion & {
		version: "2.11.0"
		sync: []
	}

	git_lfs: #ToolVersion & {
		version: "3.7.1"
		sync: []
	}

	nono: #ToolVersion & {
		version: "v0.53.0"
		sync: []
	}

	// =========================================================================
	// Protobuf tools
	// =========================================================================

	buf: #ToolVersion & {
		version: "1.69.0"
		sync: []
	}

	protoc: #ToolVersion & {
		version: "35.0"
		sync: []
	}

	// =========================================================================
	// Job queue tools
	// =========================================================================

	river: #ToolVersion & {
		version: "0.38.0"
		sync: []
	}

	// =========================================================================
	// CI / build tools
	// =========================================================================

	buildkite_cli: #ToolVersion & {
		version: "3.42.0"
		sync: []
	}

	buildkite_agent: #ToolVersion & {
		version: "3.127.0"
		sync: []
	}

	// =========================================================================
	// Bazel modules
	// =========================================================================

	bazel_skylib: #ToolVersion & {
		version: "1.9.0"
		sync: []
	}

	platforms: #ToolVersion & {
		version: "1.1.0"
		sync: []
	}

	rules_img: #ToolVersion & {
		version: "0.3.11"
		sync: []
	}

	rules_oci: #ToolVersion & {
		version: "2.3.0"
		sync: []
	}

	rules_shell: #ToolVersion & {
		version: "0.8.0"
		sync: []
	}

	rules_pkg: #ToolVersion & {
		version: "1.2.0"
		sync: []
	}

	protobuf: #ToolVersion & {
		version: "35.0"
		sync: []
	}

	rules_proto: #ToolVersion & {
		version: "7.1.0"
		sync: []
	}

	rules_proto_grpc: #ToolVersion & {
		version: "5.8.0"
		sync: []
	}

	rules_proto_grpc_go: #ToolVersion & {
		version: "5.8.0"
		sync: []
	}

	rules_java: #ToolVersion & {
		version: "9.6.1"
		sync: []
	}

	rules_cc: #ToolVersion & {
		version: "0.2.18"
		sync: []
	}

	rules_go: #ToolVersion & {
		version: "0.60.0"
		sync: []
	}

	gazelle: #ToolVersion & {
		version: "0.51.0"
		sync: []
	}

	rules_python: #ToolVersion & {
		version: "2.0.2"
		sync: []
	}

	rules_uv: #ToolVersion & {
		version: "0.89.2"
		sync: []
	}

	aspect_rules_js: #ToolVersion & {
		version: "3.1.2"
		sync: []
	}

	aspect_rules_ts: #ToolVersion & {
		version: "3.8.10"
		sync: []
	}

	rules_nodejs: #ToolVersion & {
		version: "6.7.4"
		sync: []
	}

	aspect_bazel_lib: #ToolVersion & {
		version: "2.22.5"
		sync: []
	}
}
