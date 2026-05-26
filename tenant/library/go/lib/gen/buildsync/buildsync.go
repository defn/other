// Package buildsync builds Bazel targets and syncs outputs to the workspace.
package buildsync

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// RunBuildOnly builds Bazel targets (without testing) and syncs outputs to workspace.
// Used by hatch to reach equilibrium without chicken-and-egg test failures.
func RunBuildOnly(ctx *gen.Context) error {
	return run(ctx, false)
}

// Run builds generated Bazel targets and syncs outputs to workspace.
func Run(ctx *gen.Context) error {
	return run(ctx, true)
}

func run(ctx *gen.Context, withTests bool) error {
	// Collect catalog data for sync operations
	k3dPaths := k3dClusterPaths(ctx)
	appEs := appEntries(ctx)
	appPs := make([]string, len(appEs))
	for i, e := range appEs {
		appPs[i] = appRenderPath(e)
	}
	k8sVerDirs := k8sVersionDirs(ctx)
	chartPairs := chartVersionPairs(ctx)

	// Build (and optionally test) //... in a single Bazel call.
	if withTests {
		ctx.LogOK("building and testing generated targets")
		if err := ctx.BazelTest("//..."); err != nil {
			return err
		}
	} else {
		ctx.LogOK("building generated targets (no tests)")
		if err := ctx.BazelBuild("//..."); err != nil {
			return err
		}
	}

	// Collect all sync operations
	var ops []syncOp

	// Fixed targets
	ops = append(ops,
		syncOp{"bazel-bin/package_gen.json", "package.json", "644"},
		syncOp{"bazel-bin/go_gen.mod", "go.mod", "644"},
		syncOp{"bazel-bin/go_gen.work", "go.work", "644"},
		syncOp{"bazel-bin/cue.mod/module_gen.cue", "cue.mod/module.cue", "644"},
		// root/.aws/config: generated directly by defn gen awsconfig
		// (no genrule, no sync). Pre-Stage-6 this was a cue-export
		// genrule under the active tenant's aws/ dir.
	)

	// k3d generated files
	for _, path := range k3dPaths {
		ops = append(ops,
			syncOp{"bazel-bin/" + path + "/k3d_gen.yaml", path + "/k3d.yaml", "644"},
			syncOp{"bazel-bin/" + path + "/mise_gen.toml", path + "/mise.toml", "644"},
			syncOp{"bazel-bin/" + path + "/kube_gitignore_gen", path + "/.kube/.gitignore", "644"},
		)
	}

	// Versioned app files
	for _, path := range appPs {
		for _, dir := range k8sVerDirs {
			ops = append(ops, syncOp{"bazel-bin/" + path + "/" + dir + "/gen_app.cue", path + "/" + dir + "/gen-app.cue", "644"})
		}
	}

	// Parent gen-app.cue from selected versioned subdir
	for _, e := range appEs {
		rp := appRenderPath(e)
		ops = append(ops, syncOp{"bazel-bin/" + rp + "/" + e.k8sVersionDir + "/gen_app.cue", rp + "/gen-app.cue", "644"})
	}

	// Bootstrap.yaml for envs with argocd
	ops = append(ops, bootstrapOps(ctx, appEs)...)

	// Sync all files in parallel
	ctx.LogOK("syncing to workspace")
	gen.ParallelN(16, len(ops), func(i int) error {
		syncFile(ctx, ops[i].src, ops[i].dest, ops[i].mode)
		return nil
	})

	// Generate chart digests
	return genChartDigests(ctx, chartPairs)
}

type appEntry struct {
	name          string
	path          string
	k8sVersionDir string
}

// appRenderPath is where a kustomize app's generated render lives. Per
// AIDR-00146 every kustomize app var-renders, so the render (gen-app.cue +
// versioned subdirs) is at var/app/<name>/, distinct from the source dir
// (e.path). Used for both the bazel-bin output location and the sync dest.
func appRenderPath(e appEntry) string {
	return "var/app/" + e.name
}

func k3dClusterPaths(ctx *gen.Context) []string {
	clusters := ctx.CatalogQuery("k3d_clusters")
	var paths []string
	gen.IterMap(clusters, func(_ string, v cue.Value) error {
		p, _ := gen.DecodeString(v, "path")
		paths = append(paths, p)
		return nil
	})
	return paths
}

func appEntries(ctx *gen.Context) []appEntry {
	apps := ctx.CatalogQuery("apps")
	var entries []appEntry
	gen.IterMap(apps, func(key string, v cue.Value) error {
		kind, _ := gen.DecodeString(v, "kind")
		if kind == "kustomize" {
			path, _ := gen.DecodeString(v, "path")
			verDir := gen.DecodeStringOr(v, "k8s_version_dir", "k8s-a")
			entries = append(entries, appEntry{name: gen.CueFieldKey(key), path: path, k8sVersionDir: verDir})
		}
		return nil
	})
	return entries
}

func k8sVersionDirs(ctx *gen.Context) []string {
	val, err := ctx.LoadCUEPackage("./kernel/interface/app", nil)
	if err != nil {
		return nil
	}
	vers := val.LookupPath(cue.ParsePath("k8s_versions"))
	var dirs []string
	gen.IterMap(vers, func(key string, _ cue.Value) error {
		dirs = append(dirs, gen.CueFieldKey(key))
		return nil
	})
	sort.Strings(dirs)
	return dirs
}

// appPaths returns a name -> path map for catalog.apps entries. Used
// by buildsync to locate bazel-bin artifacts regardless of which
// tenant's app/ subdirectory owns the brick.
func appPaths(ctx *gen.Context) map[string]string {
	apps := ctx.CatalogQuery("apps")
	m := map[string]string{}
	gen.IterMap(apps, func(key string, v cue.Value) error {
		name := gen.CueFieldKey(key)
		p, _ := gen.DecodeString(v, "path")
		if p != "" {
			m[name] = p
		}
		return nil
	})
	return m
}

// chartVersionPair is one (app, cluster) tuple from the merged
// chart_versions catalog. After AIDR-00072 the version data lives in
// per-tenant overlay files (tenant/<t>/catalog/chart_versions.cue) and
// only enumerates real (app, cluster) deployments -- the buildsync
// digest reader iterates these pairs, not a Cartesian product.
type chartVersionPair struct{ app, cluster string }

func chartVersionPairs(ctx *gen.Context) []chartVersionPair {
	versions := ctx.CatalogQuery("chart_versions")
	var pairs []chartVersionPair
	gen.IterMap(versions, func(appKey string, appVal cue.Value) error {
		appName := gen.CueFieldKey(appKey)
		cd := appVal.LookupPath(cue.ParsePath("cluster_digests"))
		gen.IterMap(cd, func(clusterKey string, clusterVal cue.Value) error {
			// Skip pairs without a concrete version: those are orphans
			// from an earlier gen pass (build_digest written when the
			// tenant overlay used to set this version, since dropped).
			// Including them would re-emit the orphan into
			// gen-chart-digests.cue and break `cue export -e
			// chart_versions` with an incomplete value.  See AIDR-00108.
			if !clusterVal.LookupPath(cue.ParsePath("version")).IsConcrete() {
				return nil
			}
			pairs = append(pairs, chartVersionPair{
				app:     appName,
				cluster: gen.CueFieldKey(clusterKey),
			})
			return nil
		})
		return nil
	})
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].app != pairs[j].app {
			return pairs[i].app < pairs[j].app
		}
		return pairs[i].cluster < pairs[j].cluster
	})
	return pairs
}

func syncFile(ctx *gen.Context, src, dest, mode string) {
	srcPath := filepath.Join(ctx.WorkDir, src)
	destPath := filepath.Join(ctx.WorkDir, dest)

	srcBytes, err := os.ReadFile(srcPath)
	if err != nil {
		// A missing source means the genrule didn't produce it -- usually
		// a stale syncOp left over from a tenant move. Loud failure makes
		// the next move catch this immediately instead of letting the
		// dest file silently drift (cf. argocd bootstrap.yaml in commit
		// 8204fa8e, which sat stale for a full release cycle because the
		// sync silently no-opped).
		ctx.LogOK("WARN: sync source missing: " + src + " (dest=" + dest + ")")
		return
	}

	destMode := os.FileMode(0o644)
	if mode == "755" {
		destMode = 0o755
	}

	// Skip the write when the destination already matches. os.Create
	// would unconditionally truncate and rewrite, which bumps mtime on
	// every sync even when bytes are identical -- invalidating Bazel's
	// mtime-based caches and polluting git status. The log line still
	// fires so spec/sync-files.txt lists all intended sync targets.
	needWrite := true
	if destBytes, readErr := os.ReadFile(destPath); readErr == nil {
		if info, statErr := os.Stat(destPath); statErr == nil &&
			bytes.Equal(srcBytes, destBytes) &&
			info.Mode().Perm() == destMode {
			needWrite = false
		}
	}

	if needWrite {
		os.MkdirAll(filepath.Dir(destPath), 0o755)
		if err := os.WriteFile(destPath, srcBytes, destMode); err != nil {
			return
		}
		// WriteFile honors umask, so set the mode explicitly.
		os.Chmod(destPath, destMode)
	}
	ctx.LogOK("synced: " + dest)
}

type syncOp struct{ src, dest, mode string }

func bootstrapOps(ctx *gen.Context, appEs []appEntry) []syncOp {
	envs := ctx.CatalogQuery("environments")
	plats := ctx.CatalogQuery("k8s_platforms")
	var ops []syncOp

	gen.IterMap(envs, func(_ string, env cue.Value) error {
		envPath, _ := gen.DecodeString(env, "path")
		platformsField := env.LookupPath(cue.ParsePath("platforms"))

		hasArgocd := false
		gen.IterMap(platformsField, func(pKey string, _ cue.Value) error {
			pName := gen.CueFieldKey(pKey)
			p := plats.LookupPath(cue.ParsePath(fmt.Sprintf("%q", pName)))
			appsField := p.LookupPath(cue.ParsePath("apps"))
			gen.IterMap(appsField, func(aKey string, _ cue.Value) error {
				if gen.CueFieldKey(aKey) == "argocd" {
					hasArgocd = true
				}
				return nil
			})
			return nil
		})

		if hasArgocd {
			argoVerDir := "k8s-a"
			argoPath := ""
			for _, e := range appEs {
				if strings.HasSuffix(e.path, "/app/argocd") {
					argoVerDir = e.k8sVersionDir
					// argocd is a kustomize app, so its versioned render (and the
					// app_kustomize.yaml genrule output) lives under var/app/argocd/
					// (AIDR-00146), not the source dir.
					argoPath = appRenderPath(e)
					break
				}
			}
			if argoPath != "" {
				ops = append(ops, syncOp{"bazel-bin/" + argoPath + "/" + argoVerDir + "/app_kustomize.yaml",
					envPath + "/bootstrap.yaml", "644"})
			}
		}
		return nil
	})
	return ops
}

func genChartDigests(ctx *gen.Context, chartPairs []chartVersionPair) error {
	appsPath := appPaths(ctx)
	// kustomize apps var-render (AIDR-00146); their per-cluster genrules (hence
	// helm_digest_*.txt) live under var/app/<name>/. Raw apps (incl. -crds) keep
	// their genrules in the source dir, so are NOT rerouted.
	kustomize := map[string]bool{}
	for _, e := range appEntries(ctx) {
		kustomize[e.name] = true
	}
	var lines []string
	for _, p := range chartPairs {
		appPath, ok := appsPath[p.app]
		if !ok {
			// chart_versions may reference apps not in catalog.apps (e.g.
			// -crds companions seeded by gen-crds-apps.cue). Fall back to
			// the default library location.
			appPath = "tenant/library/app/" + p.app
		}
		if kustomize[p.app] {
			appPath = "var/app/" + p.app
		}
		safeName := strings.ReplaceAll(p.cluster, "-", "_")
		digestPath := filepath.Join(ctx.WorkDir, "bazel-bin", appPath, "helm_digest_"+safeName+".txt")
		data, err := os.ReadFile(digestPath)
		if err != nil {
			return fmt.Errorf("read digest for %s (%s): %w", p.app, p.cluster, err)
		}
		digest := strings.TrimSpace(string(data))
		lines = append(lines, fmt.Sprintf("chart_versions: \"%s\": cluster_digests: \"%s\": build_digest: \"%s\"", p.app, p.cluster, digest))
	}

	content := "@experiment(aliasv2,explicitopen,shortcircuit,try)\n\n" +
		"// gen-chart-digests.cue -- generated by defn gen from Bazel build output.\n" +
		"// DO NOT EDIT. Run: mise run gen\n" +
		"package catalog\n\n" +
		strings.Join(lines, "\n") + "\n"

	if _, err := ctx.WriteCUEFmtIfChanged("var/gen-chart-digests.cue", []byte(content)); err != nil {
		return fmt.Errorf("write gen-chart-digests.cue: %w", err)
	}
	return nil
}
