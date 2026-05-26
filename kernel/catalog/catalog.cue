@experiment(aliasv2,explicitopen,shortcircuit,try)

// catalog.cue -- high-level inventory of managed resource sets.
//
// Each set defines instances that are generated into per-directory
// configurations by CUE + Bazel. Adding an instance to a set here
// triggers generation of BUILD.bazel, config files, and drift tests.
package catalog

import (
	"github.com/defn/other/kernel/schema"
	"strings"
)

// =========================================================================
// Scripting policy -- approved babashka require namespaces
// =========================================================================

scripting_policy: schema.#ScriptingPolicy & {
	approved_requires: [
		"defn",
		"spec",
		"clojure.string",
		"babashka.fs",
		"babashka.process",
	]
}

// =========================================================================
// Default tenant -- the single configurable knob a fork edits when
// reusing the kernel.
// =========================================================================
//
// Generators that stamp instances whose tenant ownership is not
// already encoded in a brick's path field (infra org generators,
// awstofu apps, k3d cluster fallbacks, AWS-account onboarding) read
// this value to know which tenant directory to write into. A fork
// reusing the kernel sets default_tenant in their tenant overlay's
// catalog/ to swap in their own tenant name; the kernel substrate
// itself contains zero "defn" references in active code (per
// AIDR-00071, kernel/tenant decoupling).
//
// Regex constrains the value to a path-safe, lowercase identifier so
// generators that interpolate it into filesystem paths
// (`tenant/\(default_tenant)/...`) cannot escape the workspace via
// path-traversal segments. Leading underscore is permitted to support
// synthetic test overlays (e.g. `_smoke` in
// kernel/spec/fork-smoke-test.clj). Per AIDR-00094 finding #10.
default_tenant: =~"^[a-z_][a-z0-9_-]*$" | *"defn"

// =========================================================================
// Mirror prefix -- per-tenant registry-mirror prefix on image refs.
// =========================================================================
//
// When set, `defn hatch helm-upgrade` normalizes image references by
// stripping this prefix before comparing pre-/post-upgrade image sets,
// so chart-mirror moves don't look like image changes. Defn ships k3d
// clusters with a local registry mirror at
// `host.k3d.internal:5000/mirror/`; the per-tenant value lives in
// tenant/<t>/catalog/. Forks with a different mirror set their own
// value; forks without a mirror leave it at "" (no-op). Per AIDR-00142.
mirror_prefix: string | *""

// =========================================================================
// AWS profile mappings -- per-purpose identities the tenant uses
// =========================================================================
//
// Schema constraint only. Auth instance lives in
// tenant/<t>/catalog/auth.cue. Decouples profile names (e.g. master-org
// SSO profile, image-registry login profile) from a hardcoded master
// profile previously embedded across kernel and tenant. Per AIDR-00101.
auth: schema.#Auth

// =========================================================================
// Image bootstrap sources -- per-payload S3 inputs the coder packer
// AMI fetches at first boot.
// =========================================================================
//
// Schema constraint only. Optional: tenants without a coder packer AMI
// (e.g. boot k3d-only tenant) omit this field. Instance lives in
// tenant/<t>/catalog/auth.cue alongside auth: because the auth.tofu
// profile is the principal that reads these buckets. Per AIDR-00104.
image_bootstrap?: schema.#ImageBootstrap

// =========================================================================
// Image builder -- where the packer AMI build runs.
// =========================================================================
//
// Schema constraint only. Optional: tenants without a coder packer
// AMI omit this field; the generator falls back to a default region.
// Instance lives in tenant/<t>/catalog/auth.cue alongside auth:
// and image_bootstrap:. Per AIDR-00106.
image_builder?: schema.#ImageBuilder

// =========================================================================
// k3d clusters
// =========================================================================

// Schema constraint only. Cluster instances live in
// tenant/<t>/catalog/clusters.cue and are unioned at load time.
k3d_clusters: [string]: schema.#K3dCluster

// =========================================================================
// k8s platforms
// =========================================================================

// Schema constraint only. Platform instances live in
// tenant/<t>/catalog/platforms.cue.
k8s_platforms: [string]: schema.#K8sPlatform

// =========================================================================
// environments
// =========================================================================

// Schema constraint only. Environment instances live in
// tenant/<t>/catalog/environments.cue.
environments: [string]: schema.#Environment

// =========================================================================
// IRSA bindings -- which apps need IRSA roles per cluster
// =========================================================================

// Schema constraint only. IRSA binding instances live in
// tenant/<t>/catalog/irsa.cue (defn-only today).
irsa_bindings: [string]: schema.#IRSABinding

// =========================================================================
// chart versions (per-app, for OCI helm chart publishing)
// =========================================================================
//
// Schema constraint only. Per-cluster (version, build_digest,
// published_digest) tuples live in tenant/<t>/catalog/chart_versions.cue
// (one per tenant that owns clusters), tenant/<t>/catalog/published-digests.cue
// (helm-bump output, per-tenant), and the buildsync-generated
// gen-chart-digests.cue rollup. Splitting per tenant keeps kernel free
// of cross-tenant references; see AIDR-00072 (chart_versions tenant decoupling).
//
// Per-cluster version means a content change for one cluster bumps only
// that cluster's chart tag, not all three. Non-cluster-scoped apps keep
// the per-cluster versions in lockstep because their digests stay equal.

chart_versions: [string]: schema.#ChartVersion

// =========================================================================
// OCI external images (pulled by crane, loaded into local Docker)
// =========================================================================

oci_images: [string]: schema.#OciImage

oci_images: {
	ubuntu: {
		name:   "ubuntu"
		source: "index.docker.io/library/ubuntu:noble"
		digest: "sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b"
		tag:    "defn.dev/external/ubuntu:noble"
	}
	golang: {
		name:   "golang"
		source: "index.docker.io/library/golang:1.24-bookworm"
		digest: "sha256:1a6d4452c65dea36aac2e2d606b01b4a029ec90cc1ae53890540ce6173ea77ac"
		tag:    "defn.dev/external/golang:1.24-bookworm"
	}
	"bazel-remote": {
		name:   "bazel-remote"
		source: "quay.io/bazel-remote/bazel-remote:latest"
		digest: "sha256:5aa4b51ded9d366d2dfa9f9dcbe68ef7efb659b097256f863ecc723f1c1748a9"
		tag:    "defn.dev/external/bazel-remote:latest"
	}
	registry: {
		name:   "registry"
		source: "index.docker.io/library/registry:2"
		digest: "sha256:a3d8aaa63ed8681a604f1dea0aa03f100d5895b6a58ace528858a7b332415373"
		tag:    "defn.dev/external/registry:2"
	}
}

// =========================================================================
// Container images (built from Dockerfiles)
// =========================================================================

container_images: [string]: schema.#ContainerImage

container_images: {
	base: {
		name:       "base"
		image_tag:  "defn.dev/devcontainer/dev:base"
		dockerfile: "Dockerfile"
		base:       "defn.dev/external/ubuntu:noble"
	}
	edge: {
		name:       "edge"
		image_tag:  "defn.dev/devcontainer/dev:edge"
		dockerfile: "Dockerfile"
		base:       "defn.dev/devcontainer/dev:base"
	}
	postgres: {
		name:       "postgres"
		image_tag:  "defn.dev/devcontainer/postgres"
		dockerfile: "Dockerfile"
		base:       "defn.dev/external/ubuntu:noble"
	}
	redis: {
		name:       "redis"
		image_tag:  "defn.dev/devcontainer/redis"
		dockerfile: "Dockerfile"
		base:       "defn.dev/external/ubuntu:noble"
	}
	registry: {
		name:       "registry"
		image_tag:  "defn.dev/devcontainer/registry"
		dockerfile: "Dockerfile"
		base:       "defn.dev/external/registry:2"
	}
	"bazel-remote": {
		name:       "bazel-remote"
		image_tag:  "defn.dev/devcontainer/bazel-remote"
		dockerfile: "Dockerfile"
		base:       "defn.dev/external/bazel-remote:latest"
	}
}

// =========================================================================
// Go bricks -- derived from brick catalog
// =========================================================================

// _components: all component bricks with a concrete implements field.
_components: {for _, b in bricks
	if b.kind == "component"
	if (b & {implements: string}).implements != _|_ {
		(b.path): b
	}}

// All bricks implementing any interface/go-cmd* interface.
// Used by defn gen go-cmd to generate modules.go.
go_commands: {for p, b in _components if strings.HasPrefix(b.implements, "kernel/interface/go-cmd") {(p): b}}

// Bricks implementing interface/go-cmd (plain cobra commands).
go_cmd_bricks: {for p, b in _components if b.implements == "kernel/interface/go-cmd" {(p): b}}

// Bricks implementing interface/go-cmd-parent (parent command groups).
go_cmd_parent_bricks: {for p, b in _components if b.implements == "kernel/interface/go-cmd-parent" {(p): b}}

// Bricks implementing interface/go-cmd-cue (CUE-validating commands).
go_cmd_cue_bricks: {for p, b in _components if b.implements == "kernel/interface/go-cmd-cue" {(p): b}}

// Bricks implementing interface/go-lib (Go library packages).
go_lib_bricks: {for p, b in _components if b.implements == "kernel/interface/go-lib" {(p): b}}

// Bricks implementing interface/slack-bot (Slack bot instances).
slack_bot_bricks: {for p, b in _components if b.implements == "kernel/interface/slack-bot" {(p): b}}

// Bricks implementing interface/discord-bot (Discord bot instances).
discord_bot_bricks: {for p, b in _components if b.implements == "kernel/interface/discord-bot" {(p): b}}

// Bricks implementing interface/gmail-bot (Gmail bot instances).
gmail_bot_bricks: {for p, b in _components if b.implements == "kernel/interface/gmail-bot" {(p): b}}

// Bricks implementing interface/matrix-bot (Matrix bot instances).
matrix_bot_bricks: {for p, b in _components if b.implements == "kernel/interface/matrix-bot" {(p): b}}

// Bricks implementing interface/telegram-bot.
telegram_bot_bricks: {for p, b in _components if b.implements == "kernel/interface/telegram-bot" {(p): b}}

// Bricks implementing kernel/interface/skill (Claude Code skills).
skill_bricks: {for p, b in _components if b.implements == "kernel/interface/skill" {(p): b}}

// Bricks implementing other Midas interfaces.
oci_bricks: {for p, b in _components if b.implements == "kernel/interface/oci" {(p): b}}
fmt_bricks: {for p, b in _components if b.implements == "kernel/interface/fmt" {(p): b}}
image_bricks: {for p, b in _components if b.implements == "kernel/interface/image" {(p): b}}
k3d_bricks: {for p, b in _components if b.implements == "kernel/interface/k3d" {(p): b}}
k8s_bricks: {for p, b in _components if b.implements == "kernel/interface/k8s" {(p): b}}
app_bricks: {for p, b in _components if b.implements == "kernel/interface/app" {(p): b}}
env_bricks: {for p, b in _components if b.implements == "kernel/interface/env" {(p): b}}
aws_bricks: {for p, b in _components if b.implements == "kernel/interface/aws" {(p): b}}
