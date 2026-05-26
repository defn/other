// Package operatorcrds generates CRD gen-app.cue files from Go API types
// using controller-gen. This enables operators built from source to have
// their CRDs automatically derived and packaged as ArgoCD raw apps.
package operatorcrds

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
)

// Operator describes a source-built operator whose CRDs should be generated.
type Operator struct {
	// TypesPath is the Go import-style path to the API types package,
	// relative to the workspace root (e.g., "v/galleybytes--terraform-operator/pkg/apis/...").
	TypesPath string
	// CRDApp is the name of the CRD app directory under app/
	// (e.g., "terraform-operator-crds").
	CRDApp string
}

// Operators lists all source-built operators with CRDs to generate.
// Add new operators here as they are hatched.
var Operators = []Operator{
	{
		TypesPath: "v/galleybytes--terraform-operator/pkg/apis/...",
		CRDApp:    "terraform-operator-crds",
	},
}

// Run generates gen-app.cue for each operator's CRD app by running
// controller-gen on the Go API types and importing the YAML into CUE.
func Run(ctx *gen.Context) error {
	for _, op := range Operators {
		if err := generateCRD(ctx, op); err != nil {
			return fmt.Errorf("operator-crds %s: %w", op.CRDApp, err)
		}
		ctx.LogOK(fmt.Sprintf("generated tenant/library/app/%s/gen-app.cue from %s", op.CRDApp, op.TypesPath))
	}
	return nil
}

func generateCRD(ctx *gen.Context, op Operator) error {
	// Create temp dir for controller-gen output.
	tmpDir, err := os.MkdirTemp("", "operator-crds-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	// Run controller-gen to produce CRD YAML.
	var combined bytes.Buffer
	if err := runner.Run(context.Background(), runner.Opts{
		Args: []string{"controller-gen", "crd",
			fmt.Sprintf("paths=./%s", op.TypesPath),
			fmt.Sprintf("output:crd:dir=%s", tmpDir)},
		Dir:    ctx.WorkDir,
		Stdout: &combined,
		Stderr: &combined,
	}); err != nil {
		return fmt.Errorf("controller-gen: %s: %w", combined.String(), err)
	}

	// Find generated YAML files.
	entries, err := os.ReadDir(tmpDir)
	if err != nil {
		return err
	}
	var yamlFiles []string
	for _, e := range entries {
		if !e.IsDir() && filepath.Ext(e.Name()) == ".yaml" {
			yamlFiles = append(yamlFiles, filepath.Join(tmpDir, e.Name()))
		}
	}
	if len(yamlFiles) == 0 {
		return fmt.Errorf("controller-gen produced no CRD files for %s", op.TypesPath)
	}

	// Import each YAML into CUE via a tmp file, then WriteIfChanged to the
	// final destination. Running `cue import --outfile <target>` directly
	// always rewrites the target, bumping mtime on every gen run even
	// when the CRDs haven't changed. Routing through a tmp file and
	// comparing bytes keeps the workspace quiet when nothing changed.
	outFile := filepath.Join(ctx.WorkDir, "tenant/library/app", op.CRDApp, "gen-app.cue")
	tmpOut := filepath.Join(tmpDir, "gen-app.cue")

	args := []string{"import", "-f", "-p", "app",
		"-l", `"objects"`, "-l", "kind", "-l", "metadata.name",
		"--outfile", tmpOut,
	}
	args = append(args, yamlFiles...)

	var importOut bytes.Buffer
	if err := runner.Run(context.Background(), runner.Opts{
		Args:   append([]string{"cue"}, args...),
		Dir:    ctx.WorkDir,
		Stdout: &importOut,
		Stderr: &importOut,
	}); err != nil {
		return fmt.Errorf("cue import: %s: %w", importOut.String(), err)
	}

	// Format the tmp file so we compare against already-formatted content.
	var fmtOut bytes.Buffer
	if err := runner.Run(context.Background(), runner.Opts{
		Args:   []string{"cue", "fmt", tmpOut},
		Dir:    ctx.WorkDir,
		Stdout: &fmtOut,
		Stderr: &fmtOut,
	}); err != nil {
		return fmt.Errorf("cue fmt: %s: %w", fmtOut.String(), err)
	}

	newContent, err := os.ReadFile(tmpOut)
	if err != nil {
		return fmt.Errorf("read tmp gen-app.cue: %w", err)
	}
	newContent = append([]byte("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\n"), newContent...)
	if _, err := gen.WriteIfChanged(outFile, newContent, 0o644); err != nil {
		return fmt.Errorf("write gen-app.cue: %w", err)
	}
	return nil
}
