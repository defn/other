# Buildkite Agent -- Vendored Source

Forked from github.com/buildkite/agent (MIT License).

## Build

```bash
CGO_ENABLED=0 go build -v -ldflags "-X github.com/buildkite/agent/v3/version.buildNumber=1" -o buildkite-agent .
```

- Pure Go, no CGO
- Version number injected via ldflags into `version.buildNumber`

## Test

```bash
go test ./...           # all tests
go test -race ./...     # with race detection
go test -cover ./...    # with coverage
```

## Lint

```bash
go tool gofumpt -extra -w .
golangci-lint run
```

## Architecture

Go CLI application with main packages:
- **[`agent/`](agent/)**: Core agent worker, job runner, log streaming, pipeline upload
- **[`api/`](api/)**: HTTP client for Buildkite API communication
- **[`core/`](core/)**: Programmatic job control interface
- **[`jobapi/`](jobapi/)**: Local HTTP server for job introspection during execution
- **[`clicommand/`](clicommand/)**: CLI command implementations
- **[`internal/`](internal/)**: Internal utilities (shell, sockets, artifacts, etc.)
- **[`process/`](process/)**: Process execution, signal handling, output streaming
- **[`logger/`](logger/)**: Structured logging
- **[`env/`](env/)**: Environment variable management

## Code Style

- Formatting with `gofumpt` in extra mode
- Struct-based configuration patterns (e.g., `AgentWorkerConfig`, `JobRunnerConfig`)
- Context-aware functions: `func Name(ctx context.Context, ...)`
- Import organization: stdlib, external deps, internal packages
- Error handling: explicit errors, wrapped with context
- Naming: PascalCase for exported, camelCase for private, ALL_CAPS for constants
- Interface types end with -er suffix where appropriate
- Uses `github.com/urfave/cli` for CLI commands
