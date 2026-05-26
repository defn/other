# tagged.bzl -- Starlark macro for tagging files with metadata.
#
# Usage in BUILD.bazel:
#   load("//kernel:tagged.bzl", "tagged_file")
#   tagged_file(name = "macos_task", src = "macos.clj", tags = ["mise-task", "clojure"])
#
# Tags are queryable via:
#   bazelisk query 'attr(tags, "\\bmise-task\\b", //...)'
#
# Implicit behavior:
#   - Tags "script" and "mise-task" imply "executable"
#   - "executable" generates an sh_test verifying the file has +x permission
#
# Tag taxonomy. Every file in m/ is tagged via tagged_file() in its
# BUILD.bazel; the manifest check enforces 100% coverage. Tags are
# queryable: bazelisk query 'attr(tags, "\\b<tag>\\b", //...)'.
#
#   Category tags (what the file is):
#     bazel-build   BUILD.bazel files
#     bazel-config  .bazelrc, .bazelversion
#     bazel-macro   .bzl macro/rule files
#     bazel-module  MODULE.bazel, WORKSPACE
#     config        Tool/project configuration
#     doc           Documentation (markdown, AIDRs)
#     generated     Generated files (e.g., CUE -> YAML)
#     patched       Files with versions patched from schema/versions.cue
#     lib           Library code (not directly executable)
#     lock          Lock files
#     mise-task     Mise task scripts (implies executable)
#     playbook      Ansible playbooks and inventory
#     script        Utility scripts (implies executable)
#     source        Source code
#
#   Language / filetype tags (format):
#     ansible, clojure, cue, edn, go, java, json, python,
#     shell, toml, typescript, yaml
#
#   Ecosystem tags (what system the file belongs to):
#     aidr, ansible, bazel, devcontainer, docker, git, mise, node, starship
#
# Implicit behavior:
#   - Tags "script" and "mise-task" automatically imply "executable".
#   - "executable" generates an sh_test verifying +x file permission.

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//kernel:fmt.bzl", _fmt_test = "fmt_test")

# Tags that imply the file must be executable.
_EXECUTABLE_TAGS = ["script", "mise-task"]

def _safe_name(src):
    """Convert a file path to a valid Bazel target name."""
    return src.replace("/", "_").replace(".", "_").replace("-", "_").replace(" ", "_")

# Extension -> (category_tags, fmt_tool)
# Every file gets a fmt_tool; use "textfmt" as the no-op fallback.
_EXT_INFO = {
    ".go": (["go", "source"], "gofmt"),
    ".cue": (["cue", "source"], "cue"),
    ".bzl": (["bazel", "bazel-macro"], "buildifier"),
    ".py": (["python", "source"], "ruff"),
    ".ts": (["typescript", "source"], "textfmt"),
    ".js": (["typescript", "source"], "textfmt"),
    ".json": (["json", "config"], "textfmt"),
    ".yaml": (["yaml", "config"], "yq"),
    ".yml": (["yaml", "config"], "yq"),
    ".toml": (["toml", "config"], "taplo"),
    ".md": (["doc"], "textfmt"),
    ".txt": (["doc"], "textfmt"),
    ".proto": (["source"], "textfmt"),
    ".lock": (["lock"], "textfmt"),
    ".graphql": (["source"], "textfmt"),
    ".clj": (["clojure", "source"], "textfmt"),
    ".edn": (["edn", "config"], "textfmt"),
    ".gz": (["generated"], "binary"),
    ".sha256": (["generated"], "binary"),
}

def _info_for_ext(src):
    """Return (category_tags, fmt_tool) for a file based on its extension."""
    for ext in _EXT_INFO:
        if src.endswith(ext):
            return _EXT_INFO[ext]
    return (["source"], "textfmt")

def tagged_package(srcs = None, exclude = []):
    """Tag and format-check all files in a package via comprehension.

    Auto-detects tags and formatters from file extensions. Generates
    tagged_file + fmt_test for each file.

    Args:
        srcs: List of files (default: glob(["**"], exclude=["BUILD.bazel"])).
        exclude: Extra patterns to exclude from glob.
    """
    if srcs == None:
        srcs = native.glob(["**"], exclude = ["BUILD.bazel"] + exclude, allow_empty = True)

    for src in srcs:
        safe = _safe_name(src)
        info = _info_for_ext(src)
        tags = info[0]
        fmt_tool = info[1]

        tagged_file(
            name = safe + "_tag",
            src = src,
            tags = tags,
        )

        if fmt_tool:
            _fmt_test(
                name = safe + "_fmt",
                tool = fmt_tool,
                src = src,
            )

def tagged_file_glob(name, srcs, tags = []):
    """Tag multiple files matching a glob pattern with the same tags.

    Args:
        name: Target name prefix.
        srcs: List of source files (typically from glob()).
        tags: List of tags applied to all files.
    """
    effective_tags = list(tags) + ["tagged"]
    native.filegroup(
        name = name,
        srcs = srcs,
        tags = effective_tags,
    )

def tagged_file(name, src, tags = []):
    """Tag a file with metadata and generate associated tests.

    Args:
        name: Target name.
        src: Source file to tag.
        tags: List of tags. "script" and "mise-task" imply "executable".
    """

    # Derive executable from category tags.
    effective_tags = list(tags)
    if "executable" not in effective_tags:
        for t in _EXECUTABLE_TAGS:
            if t in effective_tags:
                effective_tags.append("executable")
                break

    native.filegroup(
        name = name,
        srcs = [src],
        tags = effective_tags + ["tagged"],
    )

    if "executable" in effective_tags:
        defn_label = "//kernel/lib:defn.clj"

        sh_test(
            name = name + "_exec",
            srcs = ["//kernel/fmt/.mise/tasks:fmt-exec-check.clj"],
            args = ["$(location %s)" % src],
            data = [src, defn_label],
            env = {"BBS_LIB": "$(rootpath %s)" % defn_label},
            timeout = "short",
            tags = ["executable"],
        )
