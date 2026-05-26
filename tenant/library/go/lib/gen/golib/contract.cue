@experiment(aliasv2,explicitopen,shortcircuit,try)

// Contract: golib generator.
//
// Traceability:
//   Go source:      go/lib/gen/golib/golib.go
//   Reads catalogs: catalog.go_lib_bricks (entries with
//                   implements="kernel/interface/go-lib")
//   Template:       interface/go-lib/templates.cue
//
// Why these files exist: every Go library brick (~113) needs a
// BUILD.bazel with go_library (+ optional go_test) rules that list
// its sources, deps, and embeds. Hand-editing those files for 113
// bricks would be tedious and error-prone; golib scans each brick
// directory for *.go sources, reads its deps.cue (auto-generated
// from imports on first run), and stamps the BUILD.bazel from the
// interface/go-lib template.
//
// golib also supports optional files that trigger extra sections:
//   - deps.cue      -> extra _bz_deps rule
//   - test_deps.cue -> go_test rule emission
//   - contract.cue  -> fmt_test + tagged_file + exports_files
//     (the template change introduced in AIDR-00062 so
//     contract.cue files don't break the tagged_package glob)
//
// Not claimed: <path>/deps.cue, <path>/*.go, <path>/schema.cue,
// <path>/contract.cue -- all hand-written inputs. They're either
// listed in spec/manual-files.cue OR excluded from scope (most of
// go/lib/ and v/ is not yet scoped).
//
// The paths list below was derived from
//   grep -l 'implements: "kernel/interface/go-lib"' catalog/brick-*.cue
// and sorted. Refresh it when new go-lib bricks are stamped.
//
// See AIDR-00062 (generator contracts) and AIDR-00066
// (auto-claim taxonomy).
//
// This contract combines Pattern A (catalog comprehension over
// catalog.bricks filtered by stamp_type) with Pattern B (inline
// inputs block listing per-brick hand-authored files the generator
// walks; rewritten in-place by golib at the marker section below).
// For the other pattern (convention-based regex) and when to use
// each, see the "How to declare `paths`" header in
// spec/contracts-schema.cue.

package contracts

import "list"

// Bind catalog.bricks from the lattice JSON so the contract can
// iterate every go-lib brick directly (no hand-maintained mirror of
// the ~128-entry roster). Default stamp_type to "" so the
// comprehension can compare without tripping CUE's "cannot reference
// optional field" rule.
bricks: [string]: {
	path:       string
	stamp_type: string | *""
	...
}

generators: golib: {
	generator: "golib"
	source:    "tenant/library/go/lib/gen/golib"
	reason:    "stamps go_library (+ optional go_test) BUILD.bazel for every Go library brick under go/lib/ and v/ from catalog.go_lib_bricks so source-declared deps become Bazel targets automatically"
	read_from: {
		catalog: ["bricks"]
		paths: ["kernel/interface/go-lib/templates.cue"]
	}
	related_aidr: [62]
	paths: list.Concat([
		[for _, b in bricks if b.stamp_type == "go-lib" {"\(b.path)/BUILD.bazel"}],
		// In-brick source files; map populated by golib in the
		// generated inputs block at the bottom of this file.
		[for b, fs in _golib_inputs
			for f in fs {"\(b)/\(f)"}],
	])
}

// === BEGIN GENERATED: _golib_inputs ===
// Per-brick in-brick file roster emitted by golib.
// Rewritten by `mise run gen`. Do not hand-edit this section.
// Pattern B (AIDR-00093 fold): see contracts-schema.cue header.

_golib_inputs: [string]: [...string]

_golib_inputs: {
	"tenant/library/go/lib/brickpkg": ["brickpkg.go", "brickpkg_test.go", "deps.cue"]
	"tenant/library/go/lib/cli": ["command.go", "deps.cue", "latch.go", "managed.go"]
	"tenant/library/go/lib/config": ["config.go", "deps.cue", "schema.go"]
	"tenant/library/go/lib/cue": ["deps.cue", "overlay.go"]
	"tenant/library/go/lib/dispatch": ["acp.go", "agent.go", "agent_test.go", "coordmerge.go", "coordmerge_test.go", "deps.cue", "dispatch.go", "partition.go", "partition_test.go", "plan.go", "test_deps.cue", "worktree.go", "worktree_test.go"]
	"tenant/library/go/lib/gen": ["deps.cue", "exec.go", "gen.go", "log.go"]
	"tenant/library/go/lib/gen/app": ["app.go", "contract.cue", "deps.cue"]
	"tenant/library/go/lib/gen/awsconfig": ["awsconfig.go", "contract.cue", "deps.cue", "install_ec2.go", "install_ec2_test.go", "test_deps.cue"]
	"tenant/library/go/lib/gen/awstofu": ["awstofu.go", "contract.cue", "deps.cue"]
	"tenant/library/go/lib/gen/buildsync": ["buildsync.go", "contract.cue", "deps.cue"]
	"tenant/library/go/lib/gen/cuetree": ["contract.cue", "cuetree.go", "deps.cue"]
	"tenant/library/go/lib/gen/discordbot": ["contract.cue", "deps.cue", "discordbot.go"]
	"tenant/library/go/lib/gen/dispatchworker": ["contract.cue", "deps.cue", "dispatchworker.go", "dispatchworker_test.go", "test_deps.cue"]
	"tenant/library/go/lib/gen/env": ["deps.cue", "env.go"]
	"tenant/library/go/lib/gen/fmt": ["contract.cue", "deps.cue", "fmt.go"]
	"tenant/library/go/lib/gen/gmailbot": ["contract.cue", "deps.cue", "gmailbot.go"]
	"tenant/library/go/lib/gen/gocmd": ["contract.cue", "deps.cue", "gocmd.go"]
	"tenant/library/go/lib/gen/gocmdcue": ["contract.cue", "deps.cue", "gocmdcue.go"]
	"tenant/library/go/lib/gen/gocmdparent": ["contract.cue", "deps.cue", "gocmdparent.go"]
	"tenant/library/go/lib/gen/golib": ["contract.cue", "deps.cue", "golib.go"]
	"tenant/library/go/lib/gen/image": ["contract.cue", "deps.cue", "image.go"]
	"tenant/library/go/lib/gen/infra": ["contract.cue", "deps.cue", "infra.go"]
	"tenant/library/go/lib/gen/k3d": ["contract.cue", "deps.cue", "k3d.go"]
	"tenant/library/go/lib/gen/k8s": ["contract.cue", "deps.cue", "k8s.go"]
	"tenant/library/go/lib/gen/lattice": ["contract.cue", "deps.cue", "lattice.go"]
	"tenant/library/go/lib/gen/matrixbot": ["contract.cue", "deps.cue", "matrixbot.go"]
	"tenant/library/go/lib/gen/misetoml": ["contract.cue", "deps.cue", "misetoml.go"]
	"tenant/library/go/lib/gen/modulebazel": ["contract.cue", "deps.cue", "modulebazel.go"]
	"tenant/library/go/lib/gen/oci": ["contract.cue", "deps.cue", "oci.go"]
	"tenant/library/go/lib/gen/operatorcrds": ["contract.cue", "deps.cue", "operatorcrds.go"]
	"tenant/library/go/lib/gen/restamp": ["contract.cue", "deps.cue", "restamp.go"]
	"tenant/library/go/lib/gen/seed": ["contract.cue", "deps.cue", "seed.go"]
	"tenant/library/go/lib/gen/skill": ["contract.cue", "deps.cue", "skill.go"]
	"tenant/library/go/lib/gen/slackbot": ["contract.cue", "deps.cue", "slackbot.go"]
	"tenant/library/go/lib/gen/speclattice": ["contract.cue", "deps.cue", "speclattice.go"]
	"tenant/library/go/lib/gen/telegrambot": ["contract.cue", "deps.cue", "telegrambot.go"]
	"tenant/library/go/lib/gen/validate": ["deps.cue", "validate.go"]
	"tenant/library/go/lib/gen/versionsbzl": ["contract.cue", "deps.cue", "versionsbzl.go"]
	"tenant/library/go/lib/hatch": ["brick.go", "brick_test.go", "deps.cue", "gensubset.go", "gensubset_test.go", "hatch.go", "snapshot.go", "test_deps.cue"]
	"tenant/library/go/lib/log": ["deps.cue", "log.go"]
	"tenant/library/go/lib/runner": ["deps.cue", "runner.go", "runner_test.go"]
	"tenant/library/go/lib/spec/brickcollision": ["brickcollision.go", "brickcollision_test.go", "deps.cue", "test_deps.cue"]
	"tenant/library/go/lib/spec/brickreads": ["brickreads.go", "brickreads_test.go", "deps.cue", "test_deps.cue"]
	"tenant/library/go/lib/spec/crosstenantlit": ["crosstenantlit.go", "crosstenantlit_test.go", "deps.cue", "test_deps.cue"]
	"tenant/library/go/lib/stamp": ["catalog.go", "deps.cue", "helmapp.go", "midas.go", "mirror.go", "skill.go", "stamp.go"]
	"tenant/library/go/lib/tui": ["deps.cue", "tui.go"]
	"v/buildkite--agent/agent": ["agent_configuration.go", "agent_pool.go", "agent_worker.go", "agent_worker_action.go", "agent_worker_debouncer.go", "agent_worker_heartbeat.go", "agent_worker_ping.go", "agent_worker_streaming.go", "agent_worker_test.go", "baton.go", "baton_test.go", "deps.cue", "doc.go", "ec2_meta_data.go", "ec2_tags.go", "ecs_meta_data.go", "fake_api_server_test.go", "gcp_labels.go", "gcp_meta_data.go", "gcp_meta_data_test.go", "header_times_streamer.go", "header_times_streamer_test.go", "idle_monitor.go", "idle_monitor_test.go", "job_logger.go", "job_logger_test.go", "job_runner.go", "job_runner_test.go", "json_job_logger.go", "json_job_logger_test.go", "k8s_tags.go", "k8s_tags_test.go", "log_streamer.go", "log_streamer_test.go", "pipeline_uploader.go", "pipeline_uploader_test.go", "run_job.go", "tags.go", "tags_test.go", "test_deps.cue", "verify_job.go"]
	"v/buildkite--agent/agent/integration": ["config_allowlisting_integration_test.go", "deps.cue", "job_environment_integration_test.go", "job_runner_integration_test.go", "job_verification_integration_test.go", "main_test.go", "test_deps.cue", "test_helpers.go"]
	"v/buildkite--agent/agent/plugin": ["definition.go", "definition_test.go", "deps.cue", "error.go", "error_test.go", "plugin.go", "plugin_test.go", "test_deps.cue"]
	"v/buildkite--agent/api": ["agents.go", "annotations.go", "api_internal_test.go", "artifacts.go", "builds.go", "chunks.go", "client.go", "client_internal_test.go", "client_private_test.go", "client_test.go", "deps.cue", "doc.go", "github_code_access_token.go", "header_times.go", "heartbeats.go", "jobs.go", "meta_data.go", "oidc.go", "oidc_test.go", "pings.go", "pings_streaming.go", "pipelines.go", "retryable.go", "secrets.go", "secrets_test.go", "steps.go", "test_deps.cue", "token.go", "uuid.go"]
	"v/buildkite--agent/api/proto/gen": ["agentedge.pb.go", "deps.cue"]
	"v/buildkite--agent/api/proto/gen/agentedgev1connect": ["agentedge.connect.go", "deps.cue"]
	"v/buildkite--agent/clicommand": ["agent_start.go", "agent_start_test.go", "bootstrap.go", "cache_shared.go", "cancel_signal.go", "commands.go", "deps.cue", "doc.go", "env_dump.go", "env_get.go", "env_set.go", "env_unset.go", "errors.go", "global.go", "lock_acquire.go", "lock_common.go", "lock_do.go", "lock_done.go", "lock_get.go", "lock_release.go", "profiler.go", "redactor_add.go", "redactor_add_test.go", "test_deps.cue"]
	"v/buildkite--agent/cliconfig": ["deps.cue", "file.go", "loader.go"]
	"v/buildkite--agent/core": ["api_client.go", "client.go", "controller.go", "deps.cue", "doc.go", "job_controller.go", "options.go", "process_exit.go"]
	"v/buildkite--agent/env": ["deps.cue", "environment.go", "environment_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/agentapi": ["client.go", "client_server_test.go", "deps.cue", "doc.go", "lock_server.go", "lock_state.go", "paths.go", "payloads.go", "routes.go", "server.go", "test_deps.cue"]
	"v/buildkite--agent/internal/agenthttp": ["auth.go", "client.go", "deps.cue", "do.go"]
	"v/buildkite--agent/internal/artifact": ["api_client.go", "artifactory_downloader.go", "artifactory_downloader_test.go", "artifactory_uploader.go", "artifactory_uploader_test.go", "azure_blob.go", "azure_blob_downloader.go", "azure_blob_test.go", "azure_blob_uploader.go", "batch_creator.go", "bk_uploader.go", "bk_uploader_test.go", "deps.cue", "download.go", "download_test.go", "downloader.go", "downloader_test.go", "gs_downloader.go", "gs_uploader.go", "gs_uploader_test.go", "s3.go", "s3_downloader.go", "s3_downloader_test.go", "s3_test.go", "s3_uploader.go", "s3_uploader_test.go", "searcher.go", "searcher_test.go", "uploader.go", "uploader_test.go"]
	"v/buildkite--agent/internal/awslib": ["awsv2.go", "deps.cue"]
	"v/buildkite--agent/internal/cache": ["cache.go", "cache_test.go", "deps.cue", "test_deps.cue"]
	"v/buildkite--agent/internal/cryptosigner/aws": ["deps.cue", "kms.go"]
	"v/buildkite--agent/internal/cryptosigner/gcp": ["deps.cue", "kms.go", "kms_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/experiments": ["deps.cue", "experiments.go"]
	"v/buildkite--agent/internal/file": ["deps.cue", "is_opened.go", "opened_by.go"]
	"v/buildkite--agent/internal/job": ["api.go", "artifacts.go", "checkout.go", "checkout_test.go", "config.go", "config_test.go", "deps.cue", "docker.go", "executor.go", "executor_test.go", "git.go", "git_test.go", "grace.go", "knownhosts.go", "knownhosts_test.go", "plugin.go", "plugin_zip.go", "plugin_zip_test.go", "ssh.go", "ssh_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/job/githttptest": ["deps.cue", "githttptest.go"]
	"v/buildkite--agent/internal/job/hook": ["binary.go", "deps.cue", "hook.go", "main_test.go", "type.go", "type_test.go", "wrapper.go", "wrapper_test.go"]
	"v/buildkite--agent/internal/job/integration": ["artifact_integration_test.go", "checkout_git_mirrors_integration_test.go", "checkout_integration_test.go", "command_integration_test.go", "deps.cue", "doc.go", "docker_integration_test.go", "executor_tester.go", "git.go", "hooks_integration_test.go", "job_api_integration_test.go", "main_test.go", "plugin_integration_test.go", "redaction_integration_test.go", "secrets_integration_test.go"]
	"v/buildkite--agent/internal/job/integration/test-binary-hook": ["deps.cue", "main.go"]
	"v/buildkite--agent/internal/mime": ["deps.cue", "generate.go", "mime.go", "mime_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/olfactor": ["deps.cue", "olfactor.go", "olfactor_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/osutil": ["deps.cue", "doc.go", "file.go", "homedir.go", "homedir_test.go", "path.go", "path_test.go", "path_windows_test.go", "test_deps.cue", "umask.go", "umask_unix.go"]
	"v/buildkite--agent/internal/ptr": ["deps.cue", "to.go"]
	"v/buildkite--agent/internal/race": ["deps.cue", "race_disabled.go", "race_enabled.go"]
	"v/buildkite--agent/internal/redact": ["deps.cue", "redact.go", "redact_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/replacer": ["big_lipsum_test.go", "bm_redactor_test.go", "deps.cue", "mux.go", "replacer.go", "replacer_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/secrets": ["deps.cue", "doc.go", "secret.go", "secret_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/self": ["deps.cue", "self.go"]
	"v/buildkite--agent/internal/shell": ["batch.go", "deps.cue", "export_test.go", "logger.go", "logger_test.go", "lookpath.go", "main_test.go", "shell.go", "shell_test.go", "test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/shellscript": ["deps.cue", "shellscript.go", "shellscript_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/socket": ["available.go", "client.go", "client_test.go", "deps.cue", "doc.go", "middleware.go", "middleware_test.go", "server.go", "server_test.go", "test_deps.cue", "utils.go"]
	"v/buildkite--agent/internal/stdin": ["deps.cue", "main_test.go", "stdin.go", "test_deps.cue"]
	"v/buildkite--agent/internal/tempfile": ["deps.cue", "doc.go", "tempfile.go", "tempfile_test.go", "test_deps.cue"]
	"v/buildkite--agent/internal/trie": ["deps.cue", "test_deps.cue", "trie.go", "trie_test.go"]
	"v/buildkite--agent/jobapi": ["client.go", "client_test.go", "deps.cue", "doc.go", "env.go", "payloads.go", "redactions.go", "routes.go", "server.go", "server_test.go", "socket.go", "test_deps.cue"]
	"v/buildkite--agent/kubernetes": ["client.go", "deps.cue", "doc.go", "kubernetes_test.go", "runner.go", "test_deps.cue", "umask.go"]
	"v/buildkite--agent/lock": ["deps.cue", "lock.go", "lock_test.go", "test_deps.cue"]
	"v/buildkite--agent/logger": ["buffer.go", "buffer_test.go", "deps.cue", "field.go", "level.go", "log.go", "log_test.go", "test_deps.cue"]
	"v/buildkite--agent/metrics": ["deps.cue", "metrics.go"]
	"v/buildkite--agent/process": ["ansi.go", "ansi_test.go", "buffer.go", "buffer_test.go", "cat.go", "deps.cue", "export_test.go", "format.go", "main_test.go", "process.go", "process_test.go", "pty.go", "run.go", "scanner.go", "scanner_test.go", "signal.go", "signal_test.go", "test_deps.cue", "timestamper.go", "timestamper_test.go"]
	"v/buildkite--agent/status": ["deps.cue", "status.go", "status_test.go", "test_deps.cue"]
	"v/buildkite--agent/test/fixtures/hook": ["deps.cue", "main.go"]
	"v/buildkite--agent/tracetools": ["deps.cue", "doc.go", "propagate.go", "span.go"]
	"v/buildkite--agent/version": ["deps.cue", "test_deps.cue", "version.go", "version_test.go"]
	"v/cloudflare--artifact-fs/cli": ["cli.go", "deps.cue"]
	"v/cloudflare--artifact-fs/cmd/artifact-fs": ["deps.cue", "main.go"]
	"v/cloudflare--artifact-fs/internal/auth": ["deps.cue", "redact.go", "redact_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/cli": ["cli.go", "cli_test.go", "deps.cue", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/daemon": ["daemon.go", "deps.cue", "mount_check_darwin.go", "mount_check_linux.go", "status_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/fusefs": ["deps.cue", "fuse_darwin.go", "fuse_linux.go", "fuse_unix.go", "inode_attrs_unix_test.go", "merged.go", "merged_test.go", "ops.go", "readsymlink_unix_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/gitstore": ["deps.cue", "gitstore.go", "gitstore_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/hydrator": ["deps.cue", "hydrator.go", "hydrator_test.go", "inflight.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/logging": ["deps.cue", "logging.go"]
	"v/cloudflare--artifact-fs/internal/meta": ["deps.cue", "sqlite.go"]
	"v/cloudflare--artifact-fs/internal/model": ["deps.cue", "types.go"]
	"v/cloudflare--artifact-fs/internal/overlay": ["deps.cue", "store.go", "store_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/registry": ["deps.cue", "registry.go"]
	"v/cloudflare--artifact-fs/internal/snapshot": ["deps.cue", "store.go", "store_test.go", "test_deps.cue"]
	"v/cloudflare--artifact-fs/internal/watcher": ["deps.cue", "test_deps.cue", "watcher.go", "watcher_test.go"]
	"v/galleybytes--terraform-operator/pkg/apis": ["addtoscheme_tf_v1beta1.go", "apis.go", "deps.cue"]
	"v/galleybytes--terraform-operator/pkg/apis/tf": ["deps.cue", "group.go"]
	"v/galleybytes--terraform-operator/pkg/apis/tf/v1beta1": ["deps.cue", "doc.go", "helpers.go", "register.go", "terraform_types.go", "zz_generated.deepcopy.go", "zz_generated.openapi.go"]
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned": ["clientset.go", "deps.cue"]
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/fake": ["clientset_generated.go", "deps.cue", "doc.go", "register.go"]
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/scheme": ["deps.cue", "doc.go", "register.go"]
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1": ["deps.cue", "doc.go", "generated_expansion.go", "terraform.go", "tf_client.go"]
	"v/galleybytes--terraform-operator/pkg/client/clientset/versioned/typed/tf/v1beta1/fake": ["deps.cue", "doc.go", "fake_terraform.go", "fake_tf_client.go"]
	"v/galleybytes--terraform-operator/pkg/controllers": ["deps.cue", "terraform_controller.go", "terraform_controller_test.go", "test_deps.cue"]
	"v/galleybytes--terraform-operator/pkg/utils": ["deps.cue", "utils.go"]
}

// === END GENERATED: _golib_inputs ===
