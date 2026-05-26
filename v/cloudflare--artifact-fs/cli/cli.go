// Package cli re-exports the internal/cli entry point so callers outside
// v/cloudflare--artifact-fs (e.g. go/cmd/afs) can invoke the forked CLI
// without tripping Go's internal-package rule. The wrapper lives under
// the fork's parent directory, which is a valid importer of its own
// internal/ subtree, and exposes a single Run function that forwards
// unchanged.
package cli

import (
	"context"
	"io"

	internalcli "github.com/defn/other/m/v/cloudflare--artifact-fs/internal/cli"
)

// Run invokes the forked artifact-fs CLI with the given args and returns
// the process exit code. See internal/cli.Run for behavior.
func Run(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	return internalcli.Run(ctx, args, stdout, stderr)
}
