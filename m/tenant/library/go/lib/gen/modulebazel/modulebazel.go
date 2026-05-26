// Package modulebazel patches version strings into MODULE.bazel and .bazelversion.
package modulebazel

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

var bazelModules = []string{
	"bazel_skylib", "platforms", "rules_img", "rules_oci", "rules_shell",
	"rules_pkg", "toolchains_protoc", "protobuf", "rules_proto",
	"rules_proto_grpc", "rules_proto_grpc_go", "rules_java", "rules_cc",
	"rules_go", "gazelle", "rules_python", "rules_uv", "aspect_rules_js",
	"aspect_rules_ts", "rules_nodejs", "aspect_bazel_lib",
}

// Run patches MODULE.bazel and .bazelversion from schema versions.
func Run(ctx *gen.Context) error {
	versions := ctx.SchemaQuery("versions")

	ver := func(k string) string {
		return gen.DecodeStringOr(versions.LookupPath(cue.ParsePath(gen.CueFieldKey(k))), "version", "")
	}

	// --- MODULE.bazel ---
	modulePath := filepath.Join(ctx.WorkDir, "MODULE.bazel")
	content, err := os.ReadFile(modulePath)
	if err != nil {
		return fmt.Errorf("read MODULE.bazel: %w", err)
	}
	text := string(content)

	for _, mod := range bazelModules {
		v := ver(mod)
		if v == "" {
			continue
		}
		text = replaceBazelDep(text, mod, v)
	}

	// Patch root module version
	text = replacePattern(text, `(module\(\s*name\s*=\s*"defn",\s*version\s*=\s*")[^"]*`, "${1}"+ver("defn"))
	text = replacePattern(text, `(go_sdk\.download\(version\s*=\s*")[^"]*`, "${1}"+ver("go"))
	text = replacePattern(text, `(python_version\s*=\s*")[^"]*`, "${1}"+majorMinor(ver("python")))
	text = replacePattern(text, `(node_version\s*=\s*")[^"]*`, "${1}"+ver("node"))
	text = replacePattern(text, `(ts_version\s*=\s*")[^"]*`, "${1}"+ver("typescript"))

	if !strings.HasSuffix(text, "\n") {
		text += "\n"
	}
	if _, err := gen.WriteIfChanged(modulePath, []byte(text), 0o644); err != nil {
		return fmt.Errorf("write MODULE.bazel: %w", err)
	}

	// --- .bazelversion ---
	bzlVerPath := filepath.Join(ctx.WorkDir, ".bazelversion")
	if _, err := gen.WriteIfChanged(bzlVerPath, []byte(ver("bazel")+"\n"), 0o644); err != nil {
		return fmt.Errorf("write .bazelversion: %w", err)
	}

	return nil
}

func replaceBazelDep(text, modName, newVersion string) string {
	re := regexp.MustCompile(`(bazel_dep\(name\s*=\s*"` + regexp.QuoteMeta(modName) + `",\s*version\s*=\s*")[^"]*(".*?)`)
	return re.ReplaceAllString(text, "${1}"+newVersion+"${2}")
}

func replacePattern(text, pattern, replacement string) string {
	re := regexp.MustCompile(pattern)
	return re.ReplaceAllString(text, replacement)
}

func majorMinor(version string) string {
	parts := strings.SplitN(version, ".", 3)
	if len(parts) >= 2 {
		return parts[0] + "." + parts[1]
	}
	return version
}
