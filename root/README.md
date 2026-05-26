# defn

A reference implementation of agent-native platform engineering, where
structural constraints replace instructions and the git repository is a
self-validating fixed-point computation.

## Core Tenets

### The repository is a typed namespace, not a storage layer

Directories are CUE struct types. Files are typed values. Path conventions
are schema constraints. The CUE manifest comprehends the git filesystem
into a typed tree and validates it on every generation pass. A file in the
wrong place is a type error caught before any build runs.

### Configuration is a lattice, not a pipeline

CUE defines sets of valid values, not individual files. Unification (`&`)
computes the greatest lower bound -- the most constrained value consistent
with all sources. The lattice accumulates constraints monotonically: adding
information never loosens what was already constrained. A contradiction
produces bottom (`_|_`) immediately, at configuration time.

### The production loop is a fixed-point computation

CUE generates Bazel data structures. Bazel builds artifacts. Outputs are
ingested back into CUE via JSON. Git feeds CUE unification. The loop
converges when running it again produces identical output -- the state
where schema and artifacts are mutually consistent. Convergence is a
mathematical property enforced by the two-pass idempotency check in
`mise run gen`.

### Tests replace instructions

The constraint surface is encoded in a layered test suite across the git
filesystem, CUE schema, and Bazel build graph. Agents receive zero
constraint context when all tests pass. On failure, they receive exactly
the violated invariant. This outperforms prompt-based negative instructions
in completeness, precision, and token efficiency. Every test is a morphism
proving a structural relationship holds.

### Structure over enumeration

Adding a new app, environment, or platform requires adding one entry to
the CUE catalog. Directories, BUILD.bazel files, ArgoCD Applications,
namespace resources, helm chart packaging, and OCI publishing are all
derived automatically. This scales as O(rules), not O(artifacts).

### Deterministic expansion

The platform engineering project is expanding the deterministic
subcategory inside the stochastic world. CUE makes configuration
deterministic. Bazel makes builds deterministic. GitOps makes deployment
deterministic. Each expansion concentrates residual uncertainty at the
boundary with the next layer.

## BRICK: The Directory Type System

Every directory with a BUILD file is a **block** -- the atomic unit of
the platform. Blocks are classified as BRICK: Blocks, Relationships,
Interfaces, Components, Kit.

**Interfaces** define contracts -- CUE schemas, Bazel rule definitions,
type constraints. They govern what blocks must satisfy without producing
artifacts.

**Components** implement interfaces and produce artifacts -- binaries,
images, manifests, configurations. They are the concrete, typed, inert
output of the build.

### Interfaces in this repo

| Interface         | Governs                                                    |
| ----------------- | ---------------------------------------------------------- |
| `interface/app`   | App schema, kustomize macro, checksum and no-secrets tests |
| `interface/aws`   | AWS org/account definition contract                        |
| `interface/env`   | Environment schema, platform composition, chart versions   |
| `interface/k8s`   | Kubernetes platform definitions                            |
| `interface/k3d`   | k3d cluster schema, Bazel macro, config templates          |
| `interface/fmt`   | Formatter schema (tool, arguments, file patterns)          |
| `interface/oci`   | OCI external image contracts                               |
| `interface/image` | Container image build contracts                            |

### Components in this repo

| Component type           | Examples                                                                             | Produces                                         |
| ------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------ |
| **Apps** (29)            | argocd, cert-manager, capsule, reloader, traefik, kyverno, ...                       | Rendered helm charts as OCI artifacts            |
| **AWS** (1)              | aws (14 orgs, 117 accounts)                                                          | ~/.aws/config with SSO profiles                  |
| **Environments** (3)     | defn-a, defn-b, defn-c                                                               | ArgoCD Application manifests, bootstrap YAML     |
| **Platforms** (2)        | k3d-argocd, k3d-base                                                                 | Platform definitions (app sets per cluster type) |
| **Clusters** (3)         | k3d/a, k3d/b, k3d/c                                                                  | k3d cluster configs, kubeconfig, mise.toml       |
| **Formatters** (13)      | bazel, clojure, cue, go, java, json, markdown, python, shell, toml, typescript, yaml | Format rules per language                        |
| **OCI images** (3)       | ubuntu, bazel-remote, registry                                                       | Digest-pinned external image references          |
| **Container images** (6) | base, edge, postgres, redis, registry, bazel-remote                                  | Dockerfiles for devcontainer sidecars            |
| **Catalog**              | apps, platforms, environments, aws orgs/accounts, mirrors, domains, chart versions   | Source of truth for all generation               |
| **Schema**               | versions, app, aws, env, k8s, mirror, domain, brick, formatter                       | CUE type definitions                             |

## Features

### Catalog-driven generation

Define apps, platforms, environments, clusters, images, and formatters in
CUE catalogs. `mise run gen` derives everything else: BUILD.bazel files,
ArgoCD Application manifests, k3d cluster configs, OCI image directories,
namespace resources, helm chart packaging, version synchronization, and
the CUE manifest that validates the entire tree.

### Self-validating fixed-point loop

`mise run gen` runs the full generation pipeline twice. If the second
pass produces any diff, generation is not idempotent and the build fails.
`mise run check` validates the CUE manifest, runs all Bazel tests
(format, drift, checksum, structure), and confirms the repository is at
its fixed point.

### 100% file coverage via typed tagging

Every git-tracked file in the build directory has a `tagged_file()` entry
in its BUILD.bazel with category, language, filetype, and ecosystem tags.
The manifest check enforces complete coverage. Untagged files are build
errors.

### Hermetic multi-language builds

Go, Python, TypeScript, Java (GraalVM native-image), CUE, and Clojure
(Babashka) all build through Bazel with pinned toolchains and declared
dependencies. Same inputs always produce same outputs.

### Image mirror system

A catalog of upstream container images with pinned digests. `mise run
sync-mirrors` copies them to the local OCI registry using `crane index
filter` for platform-specific mirroring (linux/amd64 + linux/arm64).
Kustomize image transformers rewrite all image references to pull from
the local mirror. No external registry dependencies at deploy time.

### Helm chart OCI pipeline

Both kustomize apps (helm chart + overlay) and raw CUE apps flow through
the same pipeline: render to YAML, package as helm chart, publish to OCI
registry, deploy via ArgoCD. Chart versions, content digests, and
published digests are tracked in the catalog. `mise run helm-bump`
detects content changes and bumps versions automatically.

### Namespace automation

App namespaces are generated from platform definitions. Adding an app to
a platform in the catalog automatically creates its Namespace resource in
capsule-tenants. Bootstrap namespaces are excluded. ArgoCD does not own
namespace lifecycle.

### Environment-platform composition

Environments compose platforms. Platforms define app sets. The catalog
encodes which apps run where. Per-environment ArgoCD Application manifests
are generated with sync-wave ordering, OCI chart references, and
server-side apply.

### Format and lint as build tests

Every file has a format test as a Bazel target. Formatting is an invariant
of the fixed point. The repository only stabilizes when all output is
canonically formatted.

### Version synchronization

All tool versions live in `schema/versions.cue` with declared sync
targets. Upgrading a tool updates all files in the sync chain atomically.

### Scripting without bash

All scripts use Babashka (Clojure) via the `bbs` shebang wrapper. Shared
library in `lib/defn.clj`. The only bash in the repo is the wrapper itself.

## Quick Start

```bash
mise trust && mise install
mise exec -- bazelisk build //...
mise exec -- bazelisk test //...
mise run gen
mise run check
```

## The GitOps Equation

```
ideas' = migrate(run(deploy(build(config(ideas * world)))))
```

Each function is an observer/actuator pair. `config` is CUE unification.
`build` is Bazel hermetic compilation. `deploy` is ArgoCD + helm OCI.
`run` is Kubernetes. `migrate` is the PR that anneals world observations
back into structured intent. The feedback loop is a traced morphism, not
a pipeline. The repository is the fixed-point witness.
