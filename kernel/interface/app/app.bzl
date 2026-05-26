"""Macros for kustomize app directories."""

load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")
load("//kernel/gen-versions:cue.bzl", "CUE_VERSION")
load("//kernel/gen-versions:helm.bzl", "HELM_VERSION")
load("//kernel/gen-versions:kustomize.bzl", "KUSTOMIZE_VERSION")
load("//kernel/gen-versions:yq.bzl", "YQ_VERSION")

def app_kustomize_versioned(name, workspace_path, parent_workspace_path, chart_tgz, k8s_version, extra_srcs = [], filter_crds = True, parent_source_path = ""):
    """Generate versioned gen-app.cue for a specific k8s API version.

    Lightweight variant of app_kustomize that references the parent app's
    kustomization.yaml and chart .tgz via cross-package labels, then runs
    kustomize with the given k8s_version.

    Args:
        name: Bazel target name prefix.
        workspace_path: path relative to workspace root (e.g. "app/vcluster/k8s-1-33").
        parent_workspace_path: parent app path (e.g. "app/vcluster").
        chart_tgz: vendored helm chart tarball filename.
        k8s_version: k8s API version string (e.g. "1.33.9").
        extra_srcs: additional files from parent to copy alongside kustomization.yaml.
        parent_source_path: parent app SOURCE path holding the chart .tgz +
            extra_srcs (AIDR-00146 var/ split). Defaults to
            parent_workspace_path -- i.e. unsplit apps read chart + kustomization
            from the same parent package. When the render is evicted to var/,
            kustomization.yaml comes from parent_workspace_path (var/app/<name>)
            while the chart .tgz stays at parent_source_path (tenant/.../app/<name>).
    """

    # A non-empty parent_source_path means the render is evicted to var/
    # (AIDR-00146): gen-app.cue is NOT bundled, so on a fresh fork it is absent
    # until buildsync renders it. Glob its coverage so the first fork build
    # succeeds; the hatch loop's next pass picks up coverage once it exists.
    # Non-var apps keep gen-app.cue bundled, so reference it directly.
    _var_render = parent_source_path != ""
    if parent_source_path == "":
        parent_source_path = parent_workspace_path

    if _var_render:
        native.exports_files(native.glob(["gen-app.cue"], allow_empty = True))
    else:
        native.exports_files(["gen-app.cue"])

    _extra_labels = ["//" + parent_source_path + ":" + f for f in extra_srcs]
    _extra_cp = "".join([" cp $(location //" + parent_source_path + ":" + f + ") $$TMPWORK/ &&" for f in extra_srcs])

    # kustomize build with specific k8s version
    native.genrule(
        name = name + "_kustomize_gen",
        srcs = [
            "//" + parent_workspace_path + ":kustomization.yaml",
            "//" + parent_source_path + ":" + chart_tgz,
        ] + _extra_labels,
        outs = [name + "_kustomize.yaml"],
        cmd = " TMPWORK=$$(mktemp -d) &&" +
              " cp $(location //" + parent_workspace_path + ":kustomization.yaml) $$TMPWORK/ &&" +
              _extra_cp +
              " mkdir -p $$TMPWORK/charts &&" +
              " tar xzf $(location //" + parent_source_path + ":" + chart_tgz + ") -C $$TMPWORK/charts &&" +
              " mise x kustomize@" + KUSTOMIZE_VERSION + " helm@" + HELM_VERSION +
              " -- kustomize build --enable-helm --helm-kube-version v" + k8s_version + " $$TMPWORK" +
              " > $@ && rm -rf $$TMPWORK",
        local = True,
        visibility = ["//" + parent_workspace_path + ":__pkg__"],
    )

    # cue import yaml
    _cue_import_input = "$(location :" + name + "_kustomize_gen)"
    _experiment_prefix = "@experiment(aliasv2,explicitopen,shortcircuit,try)\\n\\n"
    _inject_experiment = (
        " && printf '" + _experiment_prefix + "' | cat - $@ > $@.tmp" +
        " && mv $@.tmp $@" +
        " && mise x cue@" + CUE_VERSION + " -- cue fmt $@"
    )
    if filter_crds:
        # Filter out CRDs -- they belong in the -crds companion app
        _cue_import_cmd = (
            "mise x yq@" + YQ_VERSION +
            " -- yq eval 'select(.kind != \"CustomResourceDefinition\")'" +
            " " + _cue_import_input + " > $@.filtered.yaml" +
            " && mise x cue@" + CUE_VERSION +
            " -- cue import -f -o $@ -p app -l '\"objects\"' -l '\"\\(kind)\"' -l '\"\\(metadata.name)\"'" +
            " $@.filtered.yaml" +
            " && mise x cue@" + CUE_VERSION + " -- cue fmt $@" +
            " && rm -f $@.filtered.yaml" +
            _inject_experiment
        )
    else:
        _cue_import_cmd = (
            "mise x cue@" + CUE_VERSION +
            " -- cue import -f -o $@ -p app -l '\"objects\"' -l '\"\\(kind)\"' -l '\"\\(metadata.name)\"'" +
            " " + _cue_import_input +
            " && mise x cue@" + CUE_VERSION + " -- cue fmt $@" +
            _inject_experiment
        )
    native.genrule(
        name = name + "_cue_import_gen",
        srcs = [":" + name + "_kustomize_gen"],
        outs = ["gen_app.cue"],
        cmd = _cue_import_cmd,
        visibility = ["//" + parent_workspace_path + ":__pkg__"],
    )

    # sync to workspace
    sh_binary(
        name = name + "_cue_sync",
        srcs = ["//gen/.mise/tasks:gen-sync.clj"],
        args = [workspace_path + "/gen-app.cue", "$(location :" + name + "_cue_import_gen)"],
        data = [":" + name + "_cue_import_gen", "//kernel/lib:defn.clj"],
        env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
    )

    # drift test + format + tags. For var-rendered apps gen-app.cue may be
    # absent on a fresh fork; glob so the first build skips coverage and the
    # hatch loop adds it once buildsync has rendered the file.
    if _var_render and not native.glob(["gen-app.cue"], allow_empty = True):
        return

    # drift test
    sh_test(
        name = name + "_cue_drift_test",
        timeout = "short",
        srcs = ["//gen/.mise/tasks:gen-drift.clj"],
        args = ["$(location gen-app.cue)", "$(location :" + name + "_cue_import_gen)"],
        data = ["gen-app.cue", ":" + name + "_cue_import_gen", "//kernel/lib:defn.clj"],
        env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
        tags = ["drift"],
    )

    # format + tags
    fmt_test(name = name + "_gen_app_cue_fmt", src = "gen-app.cue", tool = "cue")
    tagged_file(name = name + "_gen_app_cue_tag", src = "gen-app.cue", tags = ["cue", "generated"])

def app_kustomize_source(name, chart_tgz, chart_sha256 = "", extra_srcs = []):
    """Source-side rules for a var-rendered kustomize app (AIDR-00146).

    Lives in tenant/.../app/<name>/ next to the hand-written app.cue + vendored
    chart. Owns everything that must share a Bazel package with a SOURCE file:
    the chart .tgz (export + fmt + tag + checksum), app.cue export, and optional
    instance.cue / secrets.cue. The GENERATED render (gen-app.cue,
    kustomization.yaml, genrules) lives in var/app/<name>/ and is wired by
    app_kustomize_render. fmt_test/tagged_file are per-package, so a file's
    coverage rule must live in the file's own package -- hence the split.

    Args:
        name: Bazel target name prefix.
        chart_tgz: vendored helm chart tarball filename.
        chart_sha256: expected sha256 checksum of the chart tarball.
        extra_srcs: additional source files (e.g. values*.yaml) the render reads.
    """

    native.exports_files([chart_tgz, "app.cue"] + extra_srcs)

    # Checksum test: verify tarball hasn't been tampered with
    if chart_sha256:
        sh_test(
            name = name + "_checksum_test",
            timeout = "short",
            srcs = ["//kernel/interface/app:checksum-test.clj"],
            args = [
                "$(location " + chart_tgz + ")",
                chart_sha256,
            ],
            data = [
                chart_tgz,
                "//kernel/lib:defn.clj",
            ],
            env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
            tags = ["checksum"],
        )

    # instance.cue -- optional, declares multi-instance parameters
    instance_cue = native.glob(["instance.cue"], allow_empty = True)
    if instance_cue:
        native.exports_files(["instance.cue"])
        fmt_test(name = name + "_instance_cue_fmt", src = "instance.cue", tool = "cue")
        tagged_file(name = name + "_instance_cue_tag", src = "instance.cue", tags = ["cue", "source"])

    # secrets.cue -- optional, declares ESO secret requirements
    secrets_cue = native.glob(["secrets.cue"], allow_empty = True)
    if secrets_cue:
        native.exports_files(["secrets.cue"])
        fmt_test(name = name + "_secrets_cue_fmt", src = "secrets.cue", tool = "cue")
        tagged_file(name = name + "_secrets_cue_tag", src = "secrets.cue", tags = ["cue", "source"])

    # chart .tgz format + tag
    fmt_test(name = name + "_chart_tgz_fmt", src = chart_tgz, tool = "binary")
    tagged_file(name = name + "_chart_tgz_tag", src = chart_tgz, tags = ["config", "generated"])

def app_kustomize_render(name, workspace_path, k8s_version_dir = "k8s-a"):
    """Render-side rules for a var-rendered kustomize app (AIDR-00146).

    Lives in var/app/<name>/ (generated, not bundled). Owns the GENERATED
    gen-app.cue + kustomization.yaml (same package) and the cross-package wiring
    to the versioned subdir's kustomize build. The vendored chart + app.cue stay
    at the source package (app_kustomize_source). Per-cluster helm packaging
    genrules are appended below this call by defn gen.

    Args:
        name: Bazel target name prefix.
        workspace_path: var render path (e.g. "var/app/argocd").
        k8s_version_dir: versioned subdir for canonical output (default "k8s-a").
    """

    _versioned_kustomize = "//" + workspace_path + "/" + k8s_version_dir + ":" + name + "_kustomize_gen"
    _versioned_cue_import = "//" + workspace_path + "/" + k8s_version_dir + ":" + name + "_cue_import_gen"

    # kustomization.yaml is written by defn gen (present pre-build); gen-app.cue
    # is synced by buildsync post-build and is NOT bundled, so on a fresh fork
    # it is absent until the hatch loop renders it -- glob its coverage.
    _has_gen_app = native.glob(["gen-app.cue"], allow_empty = True)
    native.exports_files(_has_gen_app + ["kustomization.yaml"])

    # Sync: copy versioned gen-app.cue to the var render dir
    sh_binary(
        name = name + "_cue_sync",
        srcs = ["//gen/.mise/tasks:gen-sync.clj"],
        args = [
            workspace_path + "/gen-app.cue",
            "$(location " + _versioned_cue_import + ")",
        ],
        data = [
            _versioned_cue_import,
            "//kernel/lib:defn.clj",
        ],
        env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
    )

    # No-secrets test: rendered YAML must not contain Secret resources
    sh_test(
        name = name + "_no_secrets_test",
        timeout = "short",
        srcs = ["//kernel/interface/app:no-secrets-test.clj"],
        args = ["$(location " + _versioned_kustomize + ")"],
        data = [
            _versioned_kustomize,
            "//kernel/lib:defn.clj",
        ],
        env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
        tags = ["app"],
    )

    # No-namespaces test: namespaces are managed by capsule-tenants only
    sh_test(
        name = name + "_no_namespaces_test",
        timeout = "short",
        srcs = ["//kernel/interface/app:no-namespaces-test.clj"],
        args = ["$(location " + _versioned_kustomize + ")"],
        data = [
            _versioned_kustomize,
            "//kernel/lib:defn.clj",
        ],
        env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
        tags = ["app"],
    )

    # kustomization.yaml coverage (always present after gen)
    fmt_test(name = name + "_kustomization_yaml_fmt", src = "kustomization.yaml", tool = "yq")
    tagged_file(name = name + "_kustomization_yaml_tag", src = "kustomization.yaml", tags = ["config", "yaml"])

    # gen-app.cue coverage + drift -- glob-guarded for fresh-fork bootstrap.
    if _has_gen_app:
        sh_test(
            name = name + "_cue_drift_test",
            timeout = "short",
            srcs = ["//gen/.mise/tasks:gen-drift.clj"],
            args = [
                "$(location gen-app.cue)",
                "$(location " + _versioned_cue_import + ")",
            ],
            data = [
                "gen-app.cue",
                _versioned_cue_import,
                "//kernel/lib:defn.clj",
            ],
            env = {"BBS_LIB": "$(rootpath //kernel/lib:defn.clj)"},
            tags = ["drift"],
        )
        fmt_test(name = name + "_gen_app_cue_fmt", src = "gen-app.cue", tool = "cue")
        tagged_file(name = name + "_gen_app_cue_tag", src = "gen-app.cue", tags = ["cue", "generated"])
