# fmt.bzl -- Starlark macro for format-checking Bazel tests.
#
# Usage in BUILD.bazel:
#   load("//kernel:fmt.bzl", "fmt_test")
#   fmt_test(name = "hello_cue_fmt", tool = "cue", src = "hello.cue")
#
# Each fmt_test generates an sh_test that:
#   1. Copies the file next to the original (preserving extension)
#   2. Runs the formatter on the copy
#   3. Diffs copy against original -- any diff means the file isn't formatted
#
# To add a new formatter:
#   1. Version constant is auto-generated in gen-versions/<tool>.bzl
#   2. Add entry to _TOOL_VERSIONS below
#   3. Add formatter command to fmt/.mise/tasks/fmt-check.clj
#   4. Add tool to mise.toml

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//kernel/gen-versions:biome.bzl", "BIOME_VERSION")
load("//kernel/gen-versions:buildifier.bzl", "BUILDIFIER_VERSION")
load("//kernel/gen-versions:cljstyle.bzl", "CLJSTYLE_VERSION")
load("//kernel/gen-versions:cue.bzl", "CUE_VERSION")
load("//kernel/gen-versions:dprint.bzl", "DPRINT_VERSION")
load("//kernel/gen-versions:go.bzl", "GO_VERSION")
load("//kernel/gen-versions:google-java-format.bzl", "GOOGLE_JAVA_FORMAT_VERSION")
load("//kernel/gen-versions:java.bzl", "JAVA_VERSION")
load("//kernel/gen-versions:opentofu.bzl", "OPENTOFU_VERSION")
load("//kernel/gen-versions:packer.bzl", "PACKER_VERSION")
load("//kernel/gen-versions:prettier.bzl", "PRETTIER_VERSION")
load("//kernel/gen-versions:ruff.bzl", "RUFF_VERSION")
load("//kernel/gen-versions:shfmt.bzl", "SHFMT_VERSION")
load("//kernel/gen-versions:taplo.bzl", "TAPLO_VERSION")
load("//kernel/gen-versions:yq.bzl", "YQ_VERSION")

# Map tool names to their version constants.
_TOOL_VERSIONS = {
    "biome": BIOME_VERSION,
    "buildifier": BUILDIFIER_VERSION,
    "cljstyle": CLJSTYLE_VERSION,
    "cue": CUE_VERSION,
    "dprint": DPRINT_VERSION,
    "gofmt": GO_VERSION,
    "yae": GO_VERSION,
    "google-java-format": GOOGLE_JAVA_FORMAT_VERSION,
    "packer": PACKER_VERSION,
    "prettier": PRETTIER_VERSION,
    "ruff": RUFF_VERSION,
    "shfmt": SHFMT_VERSION,
    "taplo": TAPLO_VERSION,
    "tofu": OPENTOFU_VERSION,
    "binary": "0",
    "textfmt": "0",
    "yq": YQ_VERSION,
}

# Tools that need cue.mod/ available via parent directory traversal.
_CUE_TOOLS = ["cue"]

# Tools that need dprint.json config via parent directory traversal.
_DPRINT_TOOLS = ["dprint"]

def fmt_test(name, tool, src, extra_data = [], **kwargs):
    """Create a format-checking Bazel test.

    Args:
        name: Test target name.
        tool: Formatter name (biome, cljstyle, cue, gofmt, ruff, shfmt, taplo, yq).
        src: Source file to check.
        extra_data: Additional data dependencies.
        **kwargs: Passed through to sh_test.
    """
    if tool not in _TOOL_VERSIONS:
        fail("Unknown formatter: %s. Known: %s" % (tool, ", ".join(sorted(_TOOL_VERSIONS.keys()))))

    version = _TOOL_VERSIONS[tool]

    # Label for defn.clj -- use local label only when this BUILD is the
    # one that owns the canonical kernel/lib/defn.clj source. Bare
    # filename match is not enough: any other package (e.g.
    # .mise/tasks/) may legitimately have its own defn.clj task file
    # that shadows the lib namespace, and pointing BBS_LIB at the
    # local sibling would corrupt fmt-check's defn require.
    defn_label = "defn.clj" if (src == "defn.clj" and native.package_name() == "kernel/lib") else "//kernel/lib:defn.clj"

    data = [src] + extra_data
    if defn_label != src:
        data.append(defn_label)
    if tool in _CUE_TOOLS and src != "module.cue":
        data.append("//cue.mod:module.cue")
    if tool in _DPRINT_TOOLS and src != "dprint.json":
        data.append("//:dprint.json")

    env = {"BBS_LIB": "$(rootpath %s)" % defn_label}

    # JAR-based formatters need java and their wrapper script
    if tool == "cljstyle":
        if src != "fmt-cljstyle.clj":
            data.append("//kernel/fmt/.mise/tasks:fmt-cljstyle.clj")
        env["JAVA_VERSION"] = JAVA_VERSION
    if tool == "google-java-format":
        if src != "fmt-google-java-format.clj":
            data.append("//kernel/fmt/.mise/tasks:fmt-google-java-format.clj")
        env["JAVA_VERSION"] = JAVA_VERSION

    sh_test(
        name = name,
        srcs = ["//kernel/fmt/.mise/tasks:fmt-check.clj"],
        args = [tool, version, "$(location %s)" % src],
        data = data,
        env = env,
        timeout = kwargs.pop("timeout", "short"),
        tags = kwargs.pop("tags", []) + ["fmt"],
        **kwargs
    )
