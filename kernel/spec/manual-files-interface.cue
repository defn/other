@experiment(aliasv2,explicitopen,shortcircuit,try)

// Manual allow-list shard: kernel/interface/ -- Midas interface contracts.
//
// One of multiple manual-files-*.cue shards per AIDR-00083; sharded
// to enable parallel-write safety when bricks claim hand-written
// files concurrently. See contracts-schema.cue for the
// _manualFileShards aggregation pattern.

package contracts

_manualFileShards: interface: [
	"kernel/spec/manual-files-interface.cue",
	"kernel/interface/app/BUILD.bazel",
	"kernel/interface/app/app.bzl",
	"kernel/interface/app/app.cue",
	"kernel/interface/app/checksum-test.clj",
	"kernel/interface/app/no-namespaces-test.clj",
	"kernel/interface/app/no-secrets-test.clj",
	"kernel/interface/app/policy.cue",
	"kernel/interface/app/templates.cue",
	"kernel/interface/aws/BUILD.bazel",
	"kernel/interface/aws/aws.cue",
	"kernel/interface/aws/templates.cue",
	"kernel/interface/discord-bot/BUILD.bazel",
	"kernel/interface/discord-bot/templates.cue",
	"kernel/interface/skill/BUILD.bazel",
	"kernel/interface/skill/templates.cue",
	"kernel/interface/env/BUILD.bazel",
	"kernel/interface/env/env.cue",
	"kernel/interface/env/templates.cue",
	"kernel/interface/fmt/BUILD.bazel",
	"kernel/interface/fmt/formatter.cue",
	"kernel/interface/fmt/templates.cue",
	"kernel/interface/gmail-bot/BUILD.bazel",
	"kernel/interface/gmail-bot/templates.cue",
	"kernel/interface/go-cmd-cue/BUILD.bazel",
	"kernel/interface/go-cmd-cue/templates.cue",
	"kernel/interface/go-cmd-parent/BUILD.bazel",
	"kernel/interface/go-cmd-parent/templates.cue",
	"kernel/interface/go-cmd/BUILD.bazel",
	"kernel/interface/go-cmd/templates.cue",
	"kernel/interface/go-lib/BUILD.bazel",
	"kernel/interface/go-lib/templates.cue",
	"kernel/interface/image/BUILD.bazel",
	"kernel/interface/image/image.cue",
	"kernel/interface/image/templates.cue",
	"kernel/interface/k3d/BUILD.bazel",
	"kernel/interface/k3d/k3d.bzl",
	"kernel/interface/k3d/k3d.cue",
	"kernel/interface/k3d/templates.cue",
	"kernel/interface/k8s/BUILD.bazel",
	"kernel/interface/k8s/domain_patch.cue",
	"kernel/interface/k8s/irsa_patch.cue",
	"kernel/interface/k8s/k8s.cue",
	"kernel/interface/k8s/tailscale_patch.cue",
	"kernel/interface/k8s/templates.cue",
	"kernel/interface/matrix-bot/BUILD.bazel",
	"kernel/interface/matrix-bot/templates.cue",
	"kernel/interface/oci/BUILD.bazel",
	"kernel/interface/oci/oci.cue",
	"kernel/interface/oci/templates.cue",
	"kernel/interface/slack-bot/BUILD.bazel",
	"kernel/interface/slack-bot/templates.cue",
	"kernel/interface/telegram-bot/BUILD.bazel",
	"kernel/interface/telegram-bot/templates.cue",
]
