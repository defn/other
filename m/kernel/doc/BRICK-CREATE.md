# Creating a New Midas Brick Type

This checklist covers creating a new interface type (like `matrix-bot`)
that follows the 1:1 Midas pattern: one interface, one generator, one
stamp subcommand. See `interface/matrix-bot` as a reference implementation.

## Files to Create

### 1. Schema (`schema/<type>.cue`)

CUE schema for instances of this type. Defines the fields each instance
must provide (name, display_name, full_name, path, etc.).

```cue
#MatrixBot: {
    name:         string
    display_name: string
    full_name:    string
    path:         string
}
```

**Also**: add `fmt_test` + `tagged_file` entries in `schema/BUILD.bazel`.

### 2. Interface (`interface/<type>/templates.cue` + `BUILD.bazel`)

CUE templates that define what files the generator stamps out for each
instance. Typically: BUILD.bazel, mise.toml, .gitignore.

The `BUILD.bazel` for the interface itself exports `templates.cue` and
has fmt_test + tagged_file entries.

### 3. Generator Library (`go/internal/gen/<type>/<type>.go`)

Go package that reads the catalog query and stamps files using the
interface templates. Follow the pattern in `go/internal/gen/discordbot/`.

Needs a `deps.cue` with `//go/internal/gen` and `@org_cuelang_go//cue`.

### 4. Gen Command (`go/cmd/gen/<type>/service.go`)

Thin wrapper that creates a gen.Context and calls the generator.
Needs a `deps.cue` pointing to the gen library.

### 5. Stamp Command (`go/cmd/stamp/<type>/service.go`)

Thin wrapper that calls `stamplib.StampBrick("<type>", path, desc)`.
Needs a `deps.cue` with `//go/internal/stamp`.

## Files to Modify

### 6. Stamp InterfaceMap (`go/internal/stamp/stamp.go`)

Add the type name -> interface path mapping:

```go
"matrix-bot": "interface/matrix-bot",
```

### 7. Gen Orchestrator (`go/cmd/gen/service.go`)

Add import and phaseA entry:

```go
import "github.com/defn/defn/m/go/internal/gen/matrixbot"
// in phaseA:
{"matrix-bot", matrixbot.Run},
```

Also add to `go/cmd/gen/deps.cue`.

### 8. Catalog Entries (`catalog/bricks.cue`)

Add entries for:

- `interface/<type>` (kind: "interface", midas: true, stamping: "generator", catalog_key)
- `go/internal/gen/<type>` (kind: "component", implements: "interface/go-lib")
- `go/cmd/gen/<type>` (kind: "component", implements: "interface/go-cmd", parent: "go/cmd/gen")
- `go/cmd/stamp/<type>` (kind: "component", implements: "interface/go-cmd", parent: "go/cmd/stamp")

Add `interface/<type>` to the root kit's composes list.

### 9. Catalog Bot Declaration (`catalog/bots.cue`)

Add the typed map declaration:

```cue
matrix_bots: [string]: schema.#MatrixBot
matrix_bots: {}
```

### 10. Catalog Query (`catalog/catalog.cue`)

Add the derived query:

```cue
matrix_bot_bricks: {for p, b in _components if b.implements == "interface/matrix-bot" {(p): b}}
```

### 11. Manifest Schema (`manifest/manifest.cue`)

Add interface dir schema and register it in the interface dirs map:

```cue
#InterfaceMatrixBot: close({
    type: "dir"
    files: close({
        "BUILD.bazel":   _#reg
        "templates.cue": _#reg
    })
})
```

## Chicken-and-Egg Scenarios

### Gen needs itself to build

The gen command binary includes the new generator, but the generator's
BUILD.bazel is itself created by gen. Solution: run `mise run gen` twice.
The first run creates BUILD.bazel files for new directories. The second
run builds the updated binary that includes the new generator.

### Stamp needs gen, gen needs stamp

The stamp subcommand is wired into the binary by generated `command.go`
files. These are produced by gen. But gen needs the stamp cmd's
`service.go` and `deps.cue` to exist first. Solution:

1. Write `service.go` and `deps.cue` by hand
2. Run `mise run gen` (creates command.go and BUILD.bazel)
3. Rebuild binary: `go build -o bin/defn ./go/`
4. Now `defn stamp <type>` works

### Binary rebuild required between gen runs

After gen creates new `command.go` files, the `bin/defn` binary is stale.
Rebuild with `go build -o bin/defn ./go/` before using stamp or gen
subcommands that reference the new type.

## Verification

After creating all files:

```bash
# Generate derived files (may need 2 runs)
mise run gen
go build -o bin/defn ./go/
mise run gen

# Stamp an instance
defn stamp <type> <path>

# Generate instance files
mise run gen

# Validate everything
mise run check -- --ignore-unclean-workarea
```

Spec tests SPEC-00314 through SPEC-00320 verify Midas brick completeness
automatically as part of `mise run check`.
