// Package stamp -- midas.go creates the full chain for a new Midas interface.
package stamp

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
)

// goModule reads the Go module declaration from rootDir/go.mod. Used
// by midas-stamping to construct importpaths that match the actual
// workspace (per AIDR-00138 D5.3, kernel substrate has no hardcoded
// module names; forks rename without code edits). Returns the
// canonical "github.com/defn/other/m" if go.mod can't be parsed --
// no behavior change in upstream defn.
func goModule(rootDir string) string {
	data, err := os.ReadFile(filepath.Join(rootDir, "go.mod"))
	if err != nil {
		return "github.com/defn/other/m"
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "module "))
		}
	}
	return "github.com/defn/other/m"
}

// cueModule reads the CUE module declaration from rootDir/cue.mod/module.cue.
// Default falls back to "github.com/defn/other".
func cueModule(rootDir string) string {
	data, err := os.ReadFile(filepath.Join(rootDir, "cue.mod", "module.cue"))
	if err != nil {
		return "github.com/defn/other"
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "module:") {
			rest := strings.TrimSpace(strings.TrimPrefix(line, "module:"))
			return strings.Trim(rest, "\"")
		}
	}
	return "github.com/defn/other"
}

// StampMidas creates the full file chain for a new Midas interface type.
// All paths are resolved relative to rootDir.
// typeName is the interface name like "matrix-bot".
// desc is a human description.
func StampMidas(rootDir, typeName, desc string) error {
	if typeName == "" {
		return fmt.Errorf("type name is required (e.g. defn stamp midas my-new-bot)")
	}

	if !strings.Contains(typeName, "-") {
		return fmt.Errorf("type name must contain a dash (e.g. matrix-bot, not matrixbot)")
	}

	// Derive names
	pkg := strings.ReplaceAll(typeName, "-", "")                 // "matrixbot"
	catalogKey := strings.ReplaceAll(typeName, "-", "_") + "s"   // "matrix_bots"
	queryName := strings.TrimSuffix(catalogKey, "s") + "_bricks" // "matrix_bot_bricks"
	schemaType := "#" + toPascalCase(typeName)

	if desc == "" {
		desc = typeName + " instance contract"
	}

	fmt.Printf("stamping Midas interface: %s\n", typeName)

	if err := writeSchema(rootDir, pkg, schemaType); err != nil {
		return err
	}
	if err := writeInterface(rootDir, typeName); err != nil {
		return err
	}
	if err := writeGenLib(rootDir, typeName, pkg, catalogKey); err != nil {
		return err
	}
	if err := writeGenCmd(rootDir, pkg); err != nil {
		return err
	}
	if err := writeStampCmd(rootDir, typeName, pkg); err != nil {
		return err
	}
	if err := writeCatalogBricks(rootDir, typeName, pkg, catalogKey, desc); err != nil {
		return err
	}
	if err := appendInterfaceMap(rootDir, typeName); err != nil {
		return err
	}
	if err := appendGenOrchestrator(rootDir, typeName, pkg); err != nil {
		return err
	}
	if err := appendBotsCatalog(rootDir, pkg, catalogKey, schemaType); err != nil {
		return err
	}
	if err := appendCatalogQuery(rootDir, typeName, queryName); err != nil {
		return err
	}
	if err := appendManifestSchema(rootDir, typeName, schemaType); err != nil {
		return err
	}
	if err := appendSchemaBuild(rootDir, pkg); err != nil {
		return err
	}

	fmt.Printf("stamped Midas interface %s\n", typeName)
	fmt.Printf("next steps:\n")
	fmt.Printf("  1. mise run gen        (run twice for chicken-and-egg)\n")
	fmt.Printf("  2. go build -o bin/defn ./go/\n")
	fmt.Printf("  3. mise run gen\n")
	fmt.Printf("  4. defn stamp %s <path>\n", pkg)
	return nil
}

func toPascalCase(s string) string {
	parts := strings.Split(s, "-")
	for i, p := range parts {
		if len(p) > 0 {
			parts[i] = strings.ToUpper(p[:1]) + p[1:]
		}
	}
	return strings.Join(parts, "")
}

// stampWriteFile, stampReadFile, stampUpdateFile delegate to catalog.go exports.
// These wrappers preserve the existing call sites in this file.
var stampWriteFile = WriteFile
var stampReadFile = ReadFile
var stampUpdateFile = UpdateFile

func writeSchema(rootDir, pkg, schemaType string) error {
	return stampWriteFile(rootDir, fmt.Sprintf("kernel/schema/%s.cue", pkg), fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

package schema

// %s defines a %s instance.
%s: {
	name:         string // brick name (lowercase)
	display_name: string // capitalized display name
	full_name:    string // full name
	path:         string // brick path
}
`, schemaType, pkg, schemaType))
}

func writeInterface(rootDir, typeName string) error {
	ifacePath := "kernel/interface/" + typeName
	// In #"""..."""# raw strings, use \#() for interpolation
	rawDisplayVar := `\#(_display_name)`
	// In """...""" regular strings, use \() for interpolation
	displayVar := `\(_display_name)`
	fullVar := `\(_full_name)`

	if err := stampWriteFile(rootDir, ifacePath+"/templates.cue", fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

// templates.cue -- %s instance: BUILD.bazel, mise.toml, .gitignore.

import "`+cueModule(rootDir)+`/kernel/helpers"

_name:         string @tag(name)
_display_name: string @tag(display_name)
_full_name:    string @tag(full_name)

build_bazel: _header + "\n\n" + helpers.FmtLoads + "\n\n" + _exports + "\n\n" + helpers.BuildBazelFmt + "\n\n" + (helpers.FmtTest & {src: ".gitignore", tool: "textfmt"}).out + "\n\n" + (helpers.FmtTest & {src: "mise.toml", tool: "taplo"}).out + "\n\n" + helpers.BuildBazelTag + "\n\n" + (helpers.TaggedFile & {src: ".gitignore", tags: ["config", "git"]}).out + "\n\n" + (helpers.TaggedFile & {src: "mise.toml", tags: ["config", "generated", "mise", "toml"]}).out

_header: #"""
	"""%s '%s' -- generated by defn gen."""
	"""#

_exports: """
	exports_files([
	    ".gitignore",
	    "mise.toml",
	])
	"""

mise_toml: """
	# Bot instance: %s (%s)
	# Credentials loaded from .env (not checked in)
	[env]
	_.file = ".env"
	"""

gitignore: """
	.env
	"""
`, typeName, toPascalCase(typeName), rawDisplayVar, displayVar, fullVar)); err != nil {
		return err
	}

	return stampWriteFile(rootDir, ifacePath+"/BUILD.bazel", fmt.Sprintf(`"""%s interface -- contract for instances."""

load("//kernel:fmt.bzl", "fmt_test")
load("//kernel:tagged.bzl", "tagged_file")

exports_files([
    "templates.cue",
])

fmt_test(
    name = "build_bazel_fmt",
    src = "BUILD.bazel",
    tool = "buildifier",
)

fmt_test(
    name = "templates_cue_fmt",
    src = "templates.cue",
    tool = "cue",
)

tagged_file(
    name = "build_bazel_tag",
    src = "BUILD.bazel",
    tags = [
        "bazel",
        "bazel-build",
    ],
)

tagged_file(
    name = "templates_cue_tag",
    src = "templates.cue",
    tags = [
        "cue",
        "source",
    ],
)
`, toPascalCase(typeName)))
}

func writeGenLib(rootDir, typeName, pkg, catalogKey string) error {
	pascal := toPascalCase(typeName)
	dir := "tenant/library/go/lib/gen/" + pkg
	if err := stampWriteFile(rootDir, dir+"/deps.cue", `@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/gen",
	"@org_cuelang_go//cue",
]
`); err != nil {
		return err
	}
	return stampWriteFile(rootDir, fmt.Sprintf("%s/%s.go", dir, pkg), fmt.Sprintf(`// Package %s generates %s instance files from the catalog.
package %s

import (
	"fmt"
	"sort"

	"cuelang.org/go/cue"
	"`+goModule(rootDir)+`/tenant/library/go/lib/gen"
)

// Run generates BUILD.bazel, mise.toml, .gitignore for each %s.
func Run(ctx *gen.Context) error {
	bots := ctx.CatalogQuery("%s")

	type entry struct {
		key         string
		name        string
		displayName string
		fullName    string
		path        string
	}
	var entries []entry
	if err := gen.IterMap(bots, func(key string, val cue.Value) error {
		name, _ := gen.DecodeString(val, "name")
		displayName, _ := gen.DecodeString(val, "display_name")
		fullName, _ := gen.DecodeString(val, "full_name")
		path, _ := gen.DecodeString(val, "path")
		entries = append(entries, entry{
			key: gen.CueFieldKey(key), name: name,
			displayName: displayName, fullName: fullName, path: path,
		})
		return nil
	}); err != nil {
		return fmt.Errorf("iterate %s: %%w", err)
	}

	sort.Slice(entries, func(i, j int) bool { return entries[i].key < entries[j].key })

	for _, e := range entries {
		if err := ctx.StampFromCUE(
			"kernel/interface/%s/templates.cue", e.path,
			map[string]string{
				"name":         e.name,
				"display_name": e.displayName,
				"full_name":    e.fullName,
			},
			[]gen.StampFile{
				{Field: "build_bazel", Filename: "BUILD.bazel"},
				{Field: "mise_toml", Filename: "mise.toml"},
				{Field: "gitignore", Filename: ".gitignore"},
			},
		); err != nil {
			return fmt.Errorf("stamp %%s: %%w", e.path, err)
		}
		ctx.LogOK(fmt.Sprintf("generated %%s/", e.path))
	}
	return nil
}
`, pkg, pascal, pkg, pascal, catalogKey, catalogKey, typeName))
}

func writeGenCmd(rootDir, pkg string) error {
	dir := "tenant/library/go/cmd/gen/" + pkg
	if err := stampWriteFile(rootDir, dir+"/service.go", fmt.Sprintf(`package %s

import (
	"context"

	"`+goModule(rootDir)+`/tenant/library/go/lib/gen"
	gen%s "`+goModule(rootDir)+`/tenant/library/go/lib/gen/%s"
	"github.com/spf13/cobra"
)

type Config struct{}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, _ Config, onReady func(error)) error {
	onReady(nil)
	genCtx, err := gen.NewContext(".", nil)
	if err != nil {
		return err
	}
	return gen%s.Run(genCtx)
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(_ *cobra.Command, _ []string) Config { return Config{} }

func RegisterFlags(_ *cobra.Command) {}
`, pkg, pkg, pkg, pkg)); err != nil {
		return err
	}
	return stampWriteFile(rootDir, dir+"/deps.cue", fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/gen",
	"//tenant/library/go/lib/gen/%s",
]
`, pkg))
}

func writeStampCmd(rootDir, typeName, pkg string) error {
	dir := "tenant/library/go/cmd/stamp/" + pkg
	if err := stampWriteFile(rootDir, dir+"/service.go", fmt.Sprintf(`package %s

import (
	"context"
	"os"

	stamplib "`+goModule(rootDir)+`/tenant/library/go/lib/stamp"
	"github.com/spf13/cobra"
)

// Config holds configuration for the %s stamp subcommand.
type Config struct {
	Path string
	Desc string
}

// Service implements ServiceRunner for stamping %s bricks.
type Service struct{}

// NewService creates a new service.
func NewService() *Service { return &Service{} }

// Run stamps a %s brick.
func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	rootDir, _ := os.Getwd()
	return stamplib.StampBrick(rootDir, "%s", cfg.Path, cfg.Desc)
}

// Stop is a no-op.
func (s *Service) Stop(_ context.Context) error { return nil }

// MakeConfig assembles configuration from cobra flags and args.
func MakeConfig(_ *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		cfg.Path = args[0]
	}
	return cfg
}

// RegisterFlags registers command-specific flags.
func RegisterFlags(_ *cobra.Command) {}
`, pkg, typeName, typeName, typeName, typeName)); err != nil {
		return err
	}
	return stampWriteFile(rootDir, dir+"/deps.cue", `@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"//tenant/library/go/lib/stamp",
]
`)
}

func writeCatalogBricks(rootDir, typeName, pkg, catalogKey, desc string) error {
	ifacePath := "kernel/interface/" + typeName
	bricks := []struct{ path, kind, brickDesc, implements, parent, stampType string }{
		{ifacePath, "interface", desc, "", "", ""},
		{"tenant/library/go/lib/gen/" + pkg, "component", typeName + " generator", "kernel/interface/go-lib", "", "go-lib"},
		{"tenant/library/go/cmd/gen/" + pkg, "component", "generate " + typeName + " wiring", "kernel/interface/go-cmd", "tenant/library/go/cmd/gen", "go-cmd"},
		{"tenant/library/go/cmd/stamp/" + pkg, "component", "stamp a " + typeName + " brick", "kernel/interface/go-cmd", "tenant/library/go/cmd/stamp", "go-cmd"},
	}

	for _, b := range bricks {
		fname := "brick-" + gen.DefaultBrickSlug(b.path) + ".cue"
		content := fmt.Sprintf(`@experiment(aliasv2,explicitopen,shortcircuit,try)

package catalog

import "`+cueModule(rootDir)+`/kernel/schema"

bricks: [string]: schema.#Brick

bricks: {
	"%s": {
		path:         "%s"
		kind:         "%s"
		desc:         "%s"
		reads: []
		writes: []
`, b.path, b.path, b.kind, b.brickDesc)

		if b.implements != "" {
			content += fmt.Sprintf("\t\timplements:   \"%s\"\n", b.implements)
		}
		if b.parent != "" {
			content += fmt.Sprintf("\t\tparent:       \"%s\"\n", b.parent)
		}
		if b.stampType != "" {
			content += fmt.Sprintf("\t\tstamp_type:   \"%s\"\n", b.stampType)
		}
		if b.kind == "interface" {
			content += "\t\tmidas:        true\n"
			content += "\t\tstamping:     \"generator\"\n"
			content += fmt.Sprintf("\t\tcatalog_key:  \"%s\"\n", catalogKey)
		}
		content += "\t}\n}\n"

		if err := stampWriteFile(rootDir, filepath.Join(brickCatalogDir(b.path), fname), content); err != nil {
			return err
		}
	}
	return nil
}

func appendInterfaceMap(rootDir, typeName string) error {
	path := "tenant/library/go/lib/stamp/stamp.go"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}
	entry := fmt.Sprintf("\t\"%s\":", typeName)
	if EntryExists(content, entry) {
		return nil
	}
	idx := strings.Index(content, "var InterfaceMap")
	if idx < 0 {
		return fmt.Errorf("InterfaceMap not found in %s", path)
	}
	rest := content[idx:]
	braceIdx := strings.Index(rest, "}")
	insertAt := idx + braceIdx
	newEntry := fmt.Sprintf("\t\"%s\":    \"kernel/interface/%s\",\n", typeName, typeName)
	content = content[:insertAt] + newEntry + content[insertAt:]
	return stampUpdateFile(rootDir, path, content)
}

func appendGenOrchestrator(rootDir, typeName, pkg string) error {
	path := "tenant/library/go/cmd/gen/service.go"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}

	mod := goModule(rootDir)
	importLine := fmt.Sprintf("\t\"%s/tenant/library/go/lib/gen/%s\"", mod, pkg)
	if !EntryExists(content, importLine) {
		marker := fmt.Sprintf("\t\"%s/tenant/library/go/lib/log\"", mod)
		content = strings.Replace(content, marker, importLine+"\n"+marker, 1)
	}

	phaseEntry := fmt.Sprintf("\t{\"%s\", %s.Run},", typeName, pkg)
	if !EntryExists(content, phaseEntry) {
		marker := "}\n\n// ModuleOptions"
		content = strings.Replace(content, marker, phaseEntry+"\n"+marker, 1)
	}

	if err := stampUpdateFile(rootDir, path, content); err != nil {
		return err
	}

	depsPath := "tenant/library/go/cmd/gen/deps.cue"
	depsContent, err := stampReadFile(rootDir, depsPath)
	if err != nil {
		return err
	}
	depLine := fmt.Sprintf("\t\"//tenant/library/go/lib/gen/%s\",", pkg)
	if !EntryExists(depsContent, depLine) {
		marker := "\t\"//tenant/library/go/lib/log\","
		depsContent = strings.Replace(depsContent, marker, depLine+"\n"+marker, 1)
		return stampUpdateFile(rootDir, depsPath, depsContent)
	}
	return nil
}

func appendBotsCatalog(rootDir, pkg, catalogKey, schemaType string) error {
	path := "kernel/catalog/bots.cue"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}
	if EntryExists(content, catalogKey+":") {
		return nil
	}
	content += fmt.Sprintf("\n%s: [string]: schema.%s\n\n%s: {}\n", catalogKey, schemaType, catalogKey)
	return stampUpdateFile(rootDir, path, content)
}

func appendCatalogQuery(rootDir, typeName, queryName string) error {
	path := "kernel/catalog/catalog.cue"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}
	if EntryExists(content, queryName) {
		return nil
	}
	ifacePath := "kernel/interface/" + typeName
	entry := fmt.Sprintf("\n// Bricks implementing %s.\n%s: {for p, b in _components if b.implements == \"%s\" {(p): b}}\n", ifacePath, queryName, ifacePath)
	marker := "// Bricks implementing other Midas interfaces"
	if strings.Contains(content, marker) {
		content = strings.Replace(content, marker, entry+"\n"+marker, 1)
	} else {
		content += entry
	}
	return stampUpdateFile(rootDir, path, content)
}

func appendManifestSchema(rootDir, typeName, schemaType string) error {
	path := "kernel/manifest/manifest.cue"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}
	defName := "#Interface" + toPascalCase(typeName)
	if EntryExists(content, defName) {
		return nil
	}

	lastBot := ""
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.Contains(trimmed, "-bot\"") && strings.Contains(trimmed, "#Interface") {
			lastBot = line
		}
	}
	if lastBot != "" {
		mapEntry := fmt.Sprintf("\t\t\"%s\":%s%s", typeName, strings.Repeat(" ", max(1, 16-len(typeName))), defName)
		content = strings.Replace(content, lastBot, lastBot+"\n"+mapEntry, 1)
	}

	defBlock := fmt.Sprintf("\n%s: {\n\ttype: \"dir\"\n\tfiles: {\n\t\t\"BUILD.bazel\":   _#reg\n\t\t\"templates.cue\": _#reg\n\t}\n}\n", defName)
	lastDefEnd := -1
	lines := strings.Split(content, "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "#Interface") && strings.Contains(line, "Bot:") {
			for j := i + 1; j < len(lines); j++ {
				if lines[j] == "}" {
					lastDefEnd = j
					break
				}
			}
		}
	}
	if lastDefEnd >= 0 {
		before := strings.Join(lines[:lastDefEnd+1], "\n")
		after := strings.Join(lines[lastDefEnd+1:], "\n")
		content = before + defBlock + after
	} else {
		content += defBlock
	}

	return stampUpdateFile(rootDir, path, content)
}

func appendSchemaBuild(rootDir, pkg string) error {
	path := "kernel/schema/BUILD.bazel"
	content, err := stampReadFile(rootDir, path)
	if err != nil {
		return err
	}
	fname := pkg + ".cue"
	if EntryExists(content, fname) {
		return nil
	}

	content += fmt.Sprintf(`
fmt_test(
    name = "%s_cue_fmt",
    src = "%s",
    tool = "cue",
)

tagged_file(
    name = "%s_cue_tag",
    src = "%s",
    tags = [
        "config",
        "cue",
    ],
)
`, pkg, fname, pkg, fname)

	return stampUpdateFile(rootDir, path, content)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
