# BRICK Applied to Go

How the BRICK registers map to Go packages, and the composition patterns
that keep Go bricks well-structured.

## The Three Go Midas Bricks

### go-lib: Library Packages

A go-lib brick is a Go package that exports types and functions.

- **Block (B)**: Directory with `.go` files and `BUILD.bazel`
- **Role (R)**: The exported API surface -- public types, functions, and their signatures
- **Implementation (I)**: The package compiled by `go_library()`
- **Configuration (C)**: `deps.cue` declaring Bazel dependencies
- **Kit (K)**: Import graph position -- what imports this package, what it imports

A go-lib does NOT need to implement an interface to be useful. Its Role is
its exported API. Tests in a go-lib brick test the library in isolation
against its own contract.

### go-cmd: Binary Commands

A go-cmd brick is a cobra subcommand with the Service pattern.

- **Role (R)**: CLI interface -- flags, subcommands, exit codes, stdin/stdout contracts
- **Implementation (I)**: The wired command (`command.go` generated, `service.go` hand-written)
- **Configuration (C)**: `deps.cue` + `Config` struct + `RegisterFlags()`
- **Kit (K)**: Participates in the fx module graph via `modules.go`

Tests in a go-cmd brick test the binary's behavior, including how it uses
its library dependencies.

### go-cmd-cue: CUE-Validating Commands

Extends go-cmd with embedded CUE schemas.

- **Role (R)**: CLI behavior + embedded CUE schema contracts
- **Implementation (I)**: Command with `//go:embed schema.cue`
- **Configuration (C)**: `deps.cue` + `schema.cue` + `Config` struct

Tests verify both CLI behavior and that embedded CUE schemas validate
correctly.

## Interfaces in Go Bricks

Go interfaces are discovered by the consumer, not declared by the producer.
This is the opposite of Java. A library exports functions and types.
A consumer defines an interface if it wants to swap implementations.

### The Progression

1. **Start without interfaces.** A go-lib brick exports concrete types.
   Consumers import and use them directly.

2. **Consumer-local interfaces.** When a go-cmd brick needs testability
   at a dependency boundary (e.g., a go-lib that talks to a database),
   the cmd brick defines an interface containing only the methods it
   calls. The interface lives in the consumer, not the producer. The
   go-lib satisfies it implicitly -- it does not know the interface
   exists.

3. **Multiple consumers, separate interfaces.** Each consumer defines the
   interface it needs, containing only the methods it actually calls.
   Consumer A calls Get and Put; consumer B only calls Get. They define
   different interfaces. This is interface segregation enforced by the
   language.

4. **Extract when the graph forces it.** When consumers need to pass a
   library instance between them, consumer-local interfaces become
   incompatible types (even though the same library satisfies both).
   Type assertions appear. That is the signal to extract a shared
   interface into its own go-lib brick containing just the interface
   type. Both consumers import that brick. The library still satisfies
   the interface implicitly.

### When an Interface Brick Is Warranted

- Used in one place: lives inside that brick (not a separate brick).
- Two or more bricks agree on a contract: extract to its own go-lib
  brick.
- The interface brick's Implementation is trivial (compiles, no logic).
  Its Role is the shared contract. Its Kit relations point to every brick
  that satisfies it.

Let the dependency graph tell you when extraction is needed. Do not decide
upfront.

## Composition Patterns

### Embedding Over Inheritance

Go has no inheritance. A struct embeds another struct and gains its
methods. In brick terms, a go-lib can embed types from another go-lib
without deep hierarchy. Keep embedding shallow -- two levels deep means
rethink the type boundaries.

### Functional Options

When a brick's Configuration needs flexibility:

```go
func NewServer(opts ...Option)
```

Each Option modifies config. The constructor signature stays stable.
The Midas brick defines the Option type and defaults; concrete bricks
add their own options. The Configuration register stays composable
without breaking existing consumers.

### Middleware Chains

For go-cmd bricks (especially HTTP services), middleware composes
cross-cutting concerns: logging, auth, metrics, tracing. Each middleware
can be its own go-lib brick. The go-cmd brick composes them via
Configuration. The Kit register records which middleware bricks a
command brick uses.

### Accept Interfaces, Return Structs

Functions that accept interfaces work with any implementation. Functions
that return structs give callers the concrete type. Producer bricks
return concrete types (rich API). Consumer bricks accept narrow
interfaces (decoupled). The boundary is defined by the consumer.

### Internal Packages

Go's `internal/` directory is only importable by parent and siblings.
This maps to the Block register: `internal/` is Implementation (I),
not Role (R). Go enforces R/I separation at the filesystem level.

## Testing Strategy

### Every Brick Has Its Own Tests

Each go-lib and go-cmd brick has `_test.go` files testing the brick and
its use of dependencies.

### Table-Driven Tests

Go convention: test cases as a slice of structs, loop over them. The
test table is the executable version of the Role schema -- each row is a
case the Implementation must satisfy. Adding a constraint to the Role
means adding a row to the table.

### Testscript for Commands

go-cmd bricks use testscript (`.txtar` files) for integration tests
that verify the binary's behavior end-to-end.

### Interface Boundaries for Test Isolation

When a go-lib dependency makes testing difficult (network, filesystem,
database), the go-cmd brick defines a consumer-local interface and tests
against a fake. The interface lives in the test file or the consumer
package -- never in the producer.

## Patterns to Avoid

### No init() Functions

Package-level `init()` creates invisible side effects that break
testability and make Kit relations implicit. Use explicit constructors
(`NewFoo(deps)`) so all dependencies are visible in the function
signature. This keeps Kit honest: if a brick depends on something, it
shows up in the constructor, not hidden in an init call.

### No Premature Interface Extraction

Do not create interface bricks before the dependency graph demands it.
Start concrete. Extract when type assertions appear between consumers.

### No Deep Embedding Hierarchies

Two levels of struct embedding is a sign to rethink type boundaries.
Prefer composition via fields over embedding.

## Context Propagation

`context.Context` threads cancellation, deadlines, and request-scoped
values through call chains. For go-cmd bricks, context is how cross-brick
concerns (timeouts, tracing, auth) flow without parameter proliferation.
Context is runtime Configuration -- it carries bindings connecting this
brick's execution to the larger system.

## Error Wrapping

`fmt.Errorf("%w", err)` preserves the error chain across brick
boundaries. Consumers use `errors.Is` / `errors.As` to inspect errors
from deep dependencies without importing the dependency's error types.
This keeps Kit relations clean: depend on the interface, not the error
types.

## Go and BRICK Alignment

Go's design already pushes toward BRICK boundaries:

| Go Concept             | BRICK Register     |
| ---------------------- | ------------------ |
| Package directory      | Block (B)          |
| Exported API           | Role (R)           |
| Compiled binary        | Implementation (I) |
| Import paths           | Kit (K)            |
| Functional options     | Configuration (C)  |
| `internal/`            | R/I separation     |
| Interface satisfaction | Kit relations      |

Go programmers following Go conventions are already building bricks. The
BRICK framework names what they are doing and makes it mechanically
verifiable.
