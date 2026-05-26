@experiment(aliasv2,explicitopen,shortcircuit,try)

// manifest.cue -- first-line defense for file naming and layout.
//
// Every git-tracked file in the repo must fit one of the closed
// directory structs below. A stray file -- wrong name, wrong dir, wrong
// permission -- fails `cue vet` at gen time with "field not allowed:
// <path>", pointing at the exact path. This is the earliest layer in a
// three-layer net:
//
//   1. manifest.cue (this file) -- enforces directory layout and
//      filename patterns. Catches "file in wrong place" / "misnamed".
//   2. spec/contracts-schema.cue + per-generator contracts -- enforce
//      that every file is either claimed by a generator, matched by a
//      convention (Pattern C), or listed in spec/manual-files.cue.
//   3. //kernel/spec:contracts_vet test -- runs the above and asserts
//      orphans == [], unannouncedShared == [], manualClaimed == [].
//
// See AIDR-00062 (generator contracts) and AIDR-00066 (auto-claim
// taxonomy) for how the three layers compose. Keep this file's dir
// structs CLOSED (`close({...})`) when the file set is enumerable;
// use OPEN (`{...}` without close) only when the tree is genuinely
// variable (e.g. the `v/` vendor tree).

package manifest

// Base file types
_#reg: close({type: "file", mode: "100644"})
_#exe: close({type: "file", mode: "100755"})
_#sym: close({type: "symlink", mode: "120000"})

// repo is constrained by #Repo.
// Any file or directory in gen-manifest.cue not listed here is a unification error.
repo: #Repo

#Repo: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:              _#reg
		".bazelignore":               _#reg
		".bazelrc":                   _#reg
		".bazelrc.user-default":      _#reg
		".bazelrc.user-devcontainer": _#reg
		".bazelversion":              _#reg
		".gitignore":                 _#reg
		".npmrc":                     _#reg
		"BUILD.bazel":                _#reg
		"dprint.json":                _#reg
		"MODULE.bazel":               _#reg
		"WORKSPACE":                  _#reg
		"WORKSPACE.bazel":            _#reg
		"bb.edn":                     _#reg
		"go.mod":                     _#reg
		"go.sum":                     _#reg
		"go.work":                    _#reg
		"go.work.sum":                _#reg
		"mise.toml":                  _#reg
		"package.json":               _#reg
		"pnpm-lock.yaml":             _#reg
		"tsconfig.json":              _#reg
	})
	dirs: close({
		".devcontainer": #Devcontainer
		".mise":         #Mise
		"cue.mod":       #CueMod
		"go":            #Go
		"bin":           #Bin
		"kernel":        #Kernel
		"root":          #Root
		"tenant":        #Tenant
		"v":             #Vendor_v
		"vendor":        #Vendor

		// Movable dir kinds: each can also live inside kernel/. See
		// #MovableDirSchemas below. Listed as optional both here and
		// in #Kernel.dirs so a move between top-level and kernel/ is
		// `git mv` only -- no manifest edit. (Resolves the kernel-side
		// of coupling #5.)
		for k, s in #MovableDirSchemas {(k)?: s}

		"nono"?: #Nono
	})
})

// Movable dir kinds: things that have lived (or could live) at either
// top-level or under kernel/. Adding a new movable kind is one edit
// here; both #Repo.dirs and #Kernel.dirs accept it without further
// changes. Stage 7's catalog/, fmt/, spec/, etc. → kernel/ moves
// would have been single edits (or zero) under this scheme.
#MovableDirSchemas: {
	"aidr":         #Aidr
	"airef":        #Airef
	"catalog":      #Catalog
	"doc":          #Doc
	"fmt":          #Fmt
	"gen":          #Gen
	"gen-versions": #GenVersions
	"gross":        #Gross
	"helpers":      #Helpers
	"image":        #Image
	"interface":    #Interface
	"lib":          #Lib
	"manifest":     #Manifest
	"module":       #Module
	"oci":          #Oci
	"schema":       #Schema
	"spec":         #Spec
	"var":          #Var
}

// Kernel holds the reusable bricks machinery that every tenant depends
// on: schemas, interfaces, manifest rules, spec lattice, helpers, etc.
// Content migrates here incrementally; empty sub-dirs are optional.
#Kernel: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"fmt.bzl":       _#reg
		"tagged.bzl":    _#reg
	})
	// Same registry as #Repo.dirs uses; a kernel-axis move is just
	// `git mv`. Adding a new movable dir kind is one edit
	// (#MovableDirSchemas above).
	dirs?: close({
		for k, s in #MovableDirSchemas {(k)?: s}
	})
})

// Per-tenant container. Each subdirectory is one tenant's instance
// data (apps, clusters, AWS accounts, etc.). Tenant names match the
// CUE catalog's tenant axis. Every tenant subdirectory uses the
// shared #TenantDir schema, so adding a new tenant or moving a dir
// between tenants is a `git mv` only -- no manifest edit. (Pre-Stage-7
// the per-tenant schemas were split (#TenantBoot, #TenantLibrary,
// #TenantDefn) and every move required removing+adding entries on
// both sides; resolved 0928b3aa+ with the unified shape below.)
#Tenant: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs: {
		[string]: #TenantDir
	}
})

// Single per-tenant directory schema. Every tenant CAN have any of
// these subdirs (all optional); each subdir's content is validated
// by its own kind-specific schema.
#TenantDir: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		"app":      #App
		"aws":      #Aws
		"bot":      #Bot
		"catalog":  #TenantCatalog
		"env":      #Env
		"go":       #Go
		"infra":    #Infra
		"k3d":      #K3d
		"k3k":      #K3k
		"k8s":      #K8s
		"playbook": #Playbook
		"spec":     #TenantSpec
	})
})

// Per-tenant catalog directory: BUILD.bazel plus any number of
// `package catalog` .cue files holding instance data for that tenant.
// Files are unioned with kernel/catalog at load time.
#TenantCatalog: close({
	type: "dir"
	files: {
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		[=~"\\.cue$"]:   _#reg
	}
})

// Per-tenant spec directory: BUILD.bazel plus any number of
// `package contracts` .cue files (manual-files-*.cue shards
// listing hand-written files owned by that tenant). Files are
// unioned with kernel/spec/contracts via the gen overlay
// (AIDR-00138 D5.2 tenant-spec overlay).
#TenantSpec: close({
	type: "dir"
	files: {
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		[=~"\\.cue$"]:   _#reg
	}
})

#Devcontainer: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:              _#reg
		".zsh-entrypoint":            _#reg
		".zshrc":                     _#reg
		"BUILD.bazel":                _#reg
		"devcontainer.json":          _#reg
		"docker-compose.macos.yml":   _#reg
		"docker-compose.yml":         _#reg
		[=~"^(init|post)-.*\\.clj$"]: _#exe
	})
})

#Mise: close({
	type: "dir"
	dirs: close({
		tasks: #MiseTasks
	})
})

#MiseTasks: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		[=~"\\.clj$"]:   _#exe
		[=~"\\.go$"]:    _#exe
	})
})

#Aidr: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:        _#reg
		"BUILD.bazel":          _#reg
		[=~"^\\d{5}-.*\\.md$"]: _#reg
	})
})

#Airef: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:        _#reg
		"BUILD.bazel":          _#reg
		[=~"^\\d{5}-.*\\.md$"]: _#reg
	})
})

#Bot: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		".gitignore":    _#reg
		"BUILD.bazel":   _#reg
		"mise.toml":     _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #BotInstance
	})
})

#BotInstance: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:  _#reg
		".gitignore":     _#reg
		"BUILD.bazel":    _#reg
		"manifest.json"?: _#reg
		"mise.toml":      _#reg
	})
})

#Doc: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		[=~".+\\.md$"]:  _#reg
	})
})

#Aws: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
})

#Catalog: {
	type: "dir"
	files: {
		"dispatch.cue"?:         _#reg
		"BUILD.bazel":           _#reg
		"apps.cue":              _#reg
		"bots.cue":              _#reg
		"brick_files.bzl":       _#reg
		"bricks.cue":            _#reg
		"catalog.cue":           _#reg
		"checks.cue":            _#reg
		"formatters.cue":        _#reg
		"published-digests.cue": _#reg
		"mirror.cue":            _#reg
		"mirrors.cue":           _#reg
		"shared-bricks.cue":     _#reg
		"skills.cue":            _#reg
		[=~"^brick-.*\\.cue$"]:  _#reg

		// Sharded per-instance catalog files (AIDR-00083). Each
		// pattern matches kernel/catalog/<aggregate>-<slug>.cue.
		[=~"^skills-[a-z][a-z0-9-]*\\.cue$"]:     _#reg
		[=~"^formatters-[a-z][a-z0-9-]*\\.cue$"]: _#reg
	}
}

// Top-level var/ (a peer to kernel/ and tenant/, accepted at top-level
// via #Repo.dirs) holds workspace-derived generator outputs so kernel/
// and tenant/ change only on structural edits, never to track regen
// churn (AIDR-00145 D5.1). var/ is not bundled by bootstrap; a fork
// grows its own. Each *.cue declares the CUE package it logically
// belongs to and is re-projected into kernel/<package>/ by the gen var
// overlay.
#Var: {
	type: "dir"
	files: {
		"dispatch.cue"?:         _#reg
		"BUILD.bazel":           _#reg
		"gen-chart-digests.cue": _#reg
		"gen-manifest.cue":      _#reg
		"gen-lattice.cue":       _#reg
	}
	dirs?: close({
		"lattice": #SpecLattice
		"app":     #VarApp
	})
}

// var/app/ holds the GENERATED render of var-rendered kustomize apps
// (AIDR-00146 Unit 2): per app, the render-side BUILD.bazel (macro +
// per-cluster genrules), gen-app.cue, kustomization.yaml, and the versioned
// k8s-* subdirs. The SOURCE (app.cue, vendored chart, instance/secrets,
// dispatch.cue, thin source-side BUILD.bazel) stays at tenant/.../app/<name>/.
// var/app itself is just a parent dir -- no Bazel package, so BUILD.bazel is
// optional here (each <name>/ is the package).
#VarApp: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel"?:  _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #VarAppComponent
	})
})

#VarAppComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:      _#reg
		"BUILD.bazel":        _#reg
		"gen-app.cue":        _#reg
		"kustomization.yaml": _#reg
	})
	dirs?: close({
		[=~"^k8s-[a-z]$"]: #AppVersionedComponent
	})
})

#Bin: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:     _#reg
		"BUILD.bazel":       _#reg
		"bazel-runner":      _#exe
		"bbs":               _#exe
		"bootstrap-bazelrc": _#exe
		"defn":              _#exe
		"k3k":               _#exe
		"yae":               _#exe
		// Fork namesake-CLI shims (AIDR-00141 Stage 3.5d):
		// stampForkTenant writes bin/<tenant> as a babashka shim.
		// The regex matches default_tenant's constraint in
		// kernel/catalog/catalog.cue (excluding "defn" -- listed
		// above).
		[=~"^[a-z_][a-z0-9_-]*$"]?: _#exe
	})
})

#GenVersions: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:       _#reg
		"BUILD.bazel":         _#reg
		[=~"^[a-z].*\\.bzl$"]: _#reg
	})
})

#Go: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:      _#reg
		"BUILD.bazel":        _#reg
		[=~"^.*\\.go$"]:      _#reg
		[=~"^.*_test\\.go$"]: _#reg
	})
	dirs: close({
		cmd:      #GoCmd
		lib:      #GoInternal
		testdata: #GoTestdata
	})
})

#GoCmd: close({
	type: "dir"
	dirs: close({
		[string]: #GoPkg
	})
})

#GoInternal: close({
	type: "dir"
	dirs: close({
		[string]: #GoPkg
	})
})

#GoPkg: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:      _#reg
		"BUILD.bazel":        _#reg
		"deps.cue"?:          _#reg
		"test_deps.cue"?:     _#reg
		"schema.cue"?:        _#reg
		"contract.cue"?:      _#reg
		[=~"^.*\\.go$"]:      _#reg
		[=~"^.*_test\\.go$"]: _#reg
	})
	dirs?: close({
		"testdata"?:      #GoTestdata
		[!~"^testdata$"]: #GoPkg
	})
})

#GoTestdata: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:    _#reg
		[=~"^.*\\.txtar$"]: _#reg
	})
})

#CueMod: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"module.cue":    _#reg
	})
})

#Helpers: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:  _#reg
		"BUILD.bazel":    _#reg
		[=~"^.*\\.cue$"]: _#reg
	})
})

#Gross: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:     _#reg
		"BUILD.bazel":       _#reg
		"registry-ca.pem":   _#reg
		"registry-cert.pem": _#reg
		"registry-key.pem":  _#reg
	})
})

#Image: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		"docker":  #ImageDocker
		"packer"?: #ImagePacker
	})
})

#ImageDocker: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #ContainerImage
	})
})

#ImagePacker: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #PackerImage
	})
})

#PackerImage: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:        _#reg
		"BUILD.bazel":          _#reg
		"mise.toml"?:           _#reg
		[=~"^.*\\.pkr\\.hcl$"]: _#reg
		[=~"^.*\\.sh$"]:        _#exe
	})
})

#ContainerImage: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"Dockerfile":    _#reg
		"mise.toml":     _#reg
	})
})

#App: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #AppComponent
	})
})

#AppComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:         _#reg
		"BUILD.bazel":           _#reg
		"app.cue"?:              _#reg
		"kustomization.yaml"?:   _#reg
		"gen-app.cue"?:          _#reg
		"raw.cue"?:              _#reg
		"instance.cue"?:         _#reg
		[=~"^values.*\\.yaml$"]: _#reg
		[=~"^.*\\.tgz$"]:        _#reg
	})
	dirs?: close({
		[=~"^k8s-[a-z]$"]: #AppVersionedComponent
	})
})

#AppVersionedComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"gen-app.cue":   _#reg
	})
})

#Fmt: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs: close({
		".mise":        #Mise
		[=~"^[a-z]+$"]: #FmtComponent
	})
})

#FmtComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"formatter.cue": _#reg
	})
})

#Gen: close({
	type: "dir"
	dirs: close({
		".mise": #Mise
	})
})

#Env: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		"versions":                               #EnvVersions
		[=~"^[a-z][a-z0-9-]*$" & !~"^versions$"]: #EnvComponent
	})
})

#EnvVersions: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:  _#reg
		"BUILD.bazel":    _#reg
		[=~"^.*\\.cue$"]: _#reg
	})
})

#EnvComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:   _#reg
		"BUILD.bazel":     _#reg
		"bootstrap.yaml"?: _#reg
		"apps.yaml"?:      _#reg
	})
})

#K8s: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #K8sComponent
	})
})

#K8sComponent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"platform.cue":  _#reg
	})
})

#Interface: close({
	type: "dir"
	dirs: close({
		"app":           #InterfaceApp
		"aws":           #InterfaceAws
		"env":           #InterfaceEnv
		"fmt":           #InterfaceFmt
		"go-cmd":        #InterfaceGoCmd
		"go-cmd-cue":    #InterfaceGoCmdCue
		"go-cmd-parent": #InterfaceGoCmdParent
		"go-lib":        #InterfaceGoLib
		"image":         #InterfaceImage
		"k3d":           #InterfaceK3d
		"k8s":           #InterfaceK8s
		"oci":           #InterfaceOci
		"skill":         #InterfaceSkill
		"slack-bot":     #InterfaceSlackBot
		"discord-bot":   #InterfaceDiscordBot
		"gmail-bot":     #InterfaceGmailBot
		"matrix-bot":    #InterfaceMatrixBot
		"telegram-bot":  #InterfaceTelegramBot
	})
})

#InterfaceApp: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:          _#reg
		"BUILD.bazel":            _#reg
		"app.bzl":                _#reg
		"app.cue":                _#reg
		"checksum-test.clj":      _#exe
		"no-namespaces-test.clj": _#exe
		"no-secrets-test.clj":    _#exe
		"policy.cue":             _#reg
		"templates.cue":          _#reg
	})
})

#InterfaceAws: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"aws.cue":       _#reg
		"templates.cue": _#reg
	})
})

#InterfaceEnv: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"env.cue":       _#reg
		"templates.cue": _#reg
	})
})

#InterfaceK8s: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:       _#reg
		"BUILD.bazel":         _#reg
		"domain_patch.cue":    _#reg
		"irsa_patch.cue":      _#reg
		"tailscale_patch.cue": _#reg
		"k8s.cue":             _#reg
		"templates.cue":       _#reg
	})
})

#InterfaceFmt: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"formatter.cue": _#reg
		"templates.cue": _#reg
	})
})

#InterfaceK3d: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"k3d.bzl":       _#reg
		"k3d.cue":       _#reg
		"templates.cue": _#reg
	})
})

#InterfaceOci: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"oci.cue":       _#reg
		"templates.cue": _#reg
	})
})

#InterfaceSkill: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceSlackBot: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceDiscordBot: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceGmailBot: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceMatrixBot: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceGoCmd: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceGoCmdCue: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceGoCmdParent: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceGoLib: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	})
})

#InterfaceImage: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"image.cue":     _#reg
		"templates.cue": _#reg
	})
})

#K3d: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs: close({
		[=~"^[a-z][a-z0-9]*$"]: #K3dCluster
	})
})

#K3dCluster: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:   _#reg
		".gitignore":      _#reg
		"BUILD.bazel":     _#reg
		"apps.yaml":       _#reg
		"bootstrap.yaml"?: _#reg
		"cluster.cue":     _#reg
		"irsa.cue"?:       _#reg
		"k3d.yaml":        _#reg
		"main.tf":         _#reg
		"mise.toml":       _#reg
	})
	dirs: close({
		".kube": #K3dKube
	})
})

#K3dKube: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		".gitignore":    _#reg
	})
})

// k3k clusters live as siblings of k3d under tenant/<owner>/k3k/.
// Naming: <host-letter><index> -- a1 = first nested cluster on
// k3d cluster a. Today the brick is hand-written; a future
// k3k-cluster stamp will own the shape (see AIDR-00129 follow-ups).
#K3k: close({
	type: "dir"
	dirs: close({
		".mise":                #Mise
		[=~"^[a-z][a-z0-9]*$"]: #K3kCluster
	})
})

#K3kCluster: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"README.md":     _#reg
		"cluster.yaml":  _#reg
		"mise.toml":     _#reg
		"smoke.yaml":    _#reg
	})
	dirs: close({
		".kube": #K3dKube
	})
})

#Lib: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:    _#reg
		"BUILD.bazel":      _#reg
		"defn.clj":         _#reg
		"devcontainer.clj": _#reg
	})
})

#Manifest: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"manifest.cue":  _#reg
	})
})

#Oci: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
	dirs?: close({
		[=~"^[a-z][a-z0-9-]*$"]: #OciImage
	})
})

#OciImage: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
	})
})

#Playbook: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"inventory":     _#reg
		"macos.yaml":    _#reg
	})
})

#Root: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:    _#reg
		".bash_entrypoint": _#reg
		".bazelrc":         _#reg
		".zshrc":           _#reg
		"AGENTS.md":        _#reg
		"BUILD.bazel":      _#reg
		"LICENSE":          _#reg
		"README.md":        _#reg
		"skills.txt":       _#reg
	})
	dirs: close({
		".aws":    #RootAws
		".config": #RootConfig
		"skills":  #RootSkills
	})
})

// Claude Code skills (sp-* dirs) -- managed by the skill Midas.
// Each skill is a brick: SKILL.md is hand-edited, BUILD.bazel is
// generated, and helper content lives in one of four named subdirs
// (scripts, references, prompts, examples) whose contents are
// open-ended and convention-claimed.
#RootSkills: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:                 _#reg
		"BUILD.bazel":                   _#reg
		"obra--superpowers-LICENSE.txt": _#reg
	})
	dirs?: close({
		[=~"^sp-[a-z][a-z0-9-]*$"]: #RootSkillsSkill
	})
})

#RootSkillsSkill: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"SKILL.md":      _#reg
	})
	dirs?: close({
		"scripts"?:    #RootSkillsSubdir
		"references"?: #RootSkillsSubdir
		"prompts"?:    #RootSkillsSubdir
		"examples"?:   #RootSkillsSubdir
	})
})

// Skill helper subdir: open-ended file set; the only required file
// is BUILD.bazel (generated). Anything else is hand-edited helper
// content, claimed by the skillcontent Pattern C convention contract.
#RootSkillsSubdir: {
	type: "dir"
	files: {
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		[string]:        _#reg | _#exe
	}
}

#RootAws: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"config":        _#reg
	})
})

#RootConfig: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"starship.toml": _#reg
	})
	dirs: close({
		"mise": #RootConfigMise
	})
})

#RootConfigMise: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"config.toml":   _#reg
	})
})

#Module: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg})
	dirs?: close({[=~"^[a-z][a-z0-9-]*$"]: #ModuleComponent})
})

#ModuleComponent: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg, [=~"^.*\\.tf$"]: _#reg})
})

#Infra: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg, "mise.toml"?: _#reg})
	dirs?: close({".mise": #Mise, "global": #InfraGlobal, "org": #InfraOrgKit})
})

#InfraOrgKit: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg})
	dirs?: close({[=~"^[a-z][a-z0-9-]*$"]: #InfraOrgInstance})
})

#InfraOrgInstance: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg, "mise.toml"?: _#reg, ".terraform.lock.hcl"?: _#reg, "terraform.auto.tfvars.json"?: _#reg, [=~"^.*\\.tf$"]: _#reg})
	dirs?: close({[=~"^[a-z0-9][a-z0-9-]*$"]: #InfraAccountInstance})
})

#InfraAccountInstance: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg, "mise.toml"?: _#reg, ".terraform.lock.hcl"?: _#reg, [=~"^.*\\.tf$"]: _#reg})
})

#InfraGlobal: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg, "mise.toml"?: _#reg, ".terraform.lock.hcl"?: _#reg, [=~"^.*\\.tf$"]: _#reg})
})

// Vendored third-party modules -- each directory listed explicitly.
// Vendored source code in v/ -- deep Go package trees with BUILD.bazel, deps.cue, and source files.
// Open schema to accommodate complex vendored codebases.
#Vendor_v: {
	type: "dir"
	files?: [string]: _#reg | _#exe
	dirs?: [string]:  #Vendor_v_subtree
}

#Vendor_v_subtree: {
	type: "dir"
	files?: [string]: _#reg | _#exe
	dirs?: [string]:  #Vendor_v_subtree
}

#Vendor: close({
	type: "dir"
	files: close({"dispatch.cue"?: _#reg, "BUILD.bazel": _#reg})
	dirs?: close({
		"terraform-aws-s3-bucket": #VendorTfModule
	})
})

// Vendored TF module: BUILD.bazel + .tf files + optional README.md/LICENSE
#VendorTfModule: close({
	type: "dir"
	files: close({
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"README.md"?:    _#reg
		"LICENSE"?:      _#reg
		[=~"^.*\\.tf$"]: _#reg
	})
})

#Schema: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:  _#reg
		"BUILD.bazel":    _#reg
		[=~"^.*\\.cue$"]: _#reg
	})
})

#Spec: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:                 _#reg
		"BUILD.bazel":                   _#reg
		"brick-collision-vet-test.clj":  _#exe
		"contracts-schema.cue":          _#reg
		"contracts-vet-test.clj":        _#exe
		"cross-tenant-lit-vet-test.clj": _#exe
		"empty-tenant-probe-test.clj":   _#exe
		"fork-smoke-test.clj":           _#exe
		"gen-files.txt":                 _#reg
		"known-shared.cue":              _#reg
		"lattice-schema-test.clj":       _#exe
		"lattice-schema.cue":            _#reg
		"lattice.cue":                   _#reg
		"mise.toml":                     _#reg
		"sync-files.txt":                _#reg
		"tenant-deps.bzl":               _#reg
		"tenant-stamp-smoke-test.clj":   _#exe
		"timing.cue":                    _#reg

		// Sharded manual-files-<slug>.cue and convention-contracts-*.cue
		// per AIDR-00083. Pattern match means adding a shard requires
		// no manifest edit. Filename convention enforced by the regex.
		[=~"^manual-files(-[a-z][a-z0-9-]*)?\\.cue$"]:         _#reg
		[=~"^convention-contracts(-[a-z][a-z0-9-]*)?\\.cue$"]: _#reg
	})
	dirs: close({
		"dispatch": #SpecDispatch
	})
})

// kernel/spec/dispatch/ holds the AIDR-00132 coordinator dispatch
// protocol schema. Hand-edited substrate; importable as
// github.com/defn/other/m/kernel/spec/dispatch.
#SpecDispatch: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:     _#reg
		"BUILD.bazel":       _#reg
		"dispatch_plan.cue": _#reg
	})
})

// var/lattice/ holds the sharded lattice payload produced by
// go/lib/gen/lattice (moved out of kernel/spec/ to the volatile
// top-level var/ dir per AIDR-00145 D5.1). BUILD.bazel is
// hand-written; everything else is generated -- one
// _index.{json,sha256} pair plus one shard per top-level lattice key
// (and per top-level repo dir under tree.dirs). Plain JSON below 64 KB
// raw, gzipped above.
#SpecLattice: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:                     _#reg
		"BUILD.bazel":                       _#reg
		"_index.json":                       _#reg
		"_index.sha256":                     _#reg
		[=~"^[A-Za-z0-9_.-]+\\.json$"]:      _#reg
		[=~"^[A-Za-z0-9_.-]+\\.json\\.gz$"]: _#reg
	})
})

#InterfaceTelegramBot: {
	type: "dir"
	files: {
		"dispatch.cue"?: _#reg
		"BUILD.bazel":   _#reg
		"templates.cue": _#reg
	}
}

// nono/ holds named nono sandbox profile JSON files.
// Profile names follow nono's naming rule: alphanumeric + hyphens.
#Nono: close({
	type: "dir"
	files: close({
		"dispatch.cue"?:                _#reg
		"BUILD.bazel":                  _#reg
		[=~"^[a-z][a-z0-9-]*\\.json$"]: _#reg
	})
})
