// Package cue provides utilities for validating configuration files (YAML/JSON)
// against CUE schemas using an in-memory overlay filesystem.
package cue

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"strings"
	"testing/fstest"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
	"cuelang.org/go/encoding/json"
	"cuelang.org/go/encoding/yaml"
)

const (
	configPrefix = "/config"
	modulePath   = "/cue.mod/module.cue"
	pkgPrefix    = "/cue.mod/pkg"
)

// OverlayFS provides an in-memory overlay filesystem for CUE schema validation.
type OverlayFS struct {
	Context   *cue.Context
	ContentFS map[string][]byte
}

// NewOverlay creates a new OverlayFS with an empty content map and fresh CUE context.
func NewOverlay() OverlayFS {
	return OverlayFS{
		Context:   cuecontext.New(),
		ContentFS: make(map[string][]byte),
	}
}

// ValidateConfig validates a configuration file against a CUE schema.
func (o OverlayFS) ValidateConfig(module, packageName, configFilePath, schemaLabel, config string, schemaFiles fs.FS) error {
	absPath, err := filepath.Abs(configFilePath)
	if err != nil {
		return err
	}

	built, err := o.BuildSchema(packageName, module, config, schemaFiles)
	if err != nil {
		return err
	}

	def := built.LookupPath(cue.ParsePath(schemaLabel))
	if err := def.Validate(); err != nil {
		return err
	}

	ext := filepath.Ext(absPath)
	inputPath := configPrefix + ext
	data, err := os.ReadFile(absPath)
	if err != nil {
		return err
	}
	o.ContentFS[inputPath] = data

	val, err := o.ParseConfigData(inputPath, data)
	if err != nil {
		return err
	}
	if err := val.Err(); err != nil {
		return err
	}

	unified := val.Unify(def)
	if err := unified.Validate(cue.Concrete(true)); err != nil {
		return err
	}

	return nil
}

// BuildSchema sets up a CUE module structure in the overlay and builds it.
func (o OverlayFS) BuildSchema(packageName, module, config string, schemaFiles fs.FS) (cue.Value, error) {
	if schemaFiles != nil {
		if err := o.AddSchema(pkgPrefix+"/"+packageName, schemaFiles); err != nil {
			return cue.Value{}, err
		}
	}

	o.AddFile(modulePath, module)
	o.AddFile(configPrefix+".cue", config)

	instances := load.Instances([]string{"."}, o.loadConfig())
	if instances[0].Err != nil {
		return cue.Value{}, instances[0].Err
	}

	built := o.Context.BuildInstance(instances[0])
	if built.Err() != nil {
		return cue.Value{}, built.Err()
	}

	return built, nil
}

// ParseConfigData parses YAML or JSON data into a CUE value.
func (o OverlayFS) ParseConfigData(configPath string, data []byte) (cue.Value, error) {
	ext := filepath.Ext(configPath)
	switch ext {
	case ".yaml", ".yml":
		f, err := yaml.Extract(filepath.Base(configPath), data)
		if err != nil {
			return cue.Value{}, err
		}
		return o.Context.BuildFile(f), nil
	case ".json":
		f, err := json.Extract(filepath.Base(configPath), data)
		if err != nil {
			return cue.Value{}, err
		}
		return o.Context.BuildExpr(f), nil
	default:
		return cue.Value{}, fmt.Errorf("unsupported config extension: %s", ext)
	}
}

// AddFile adds a single file to the overlay.
func (o OverlayFS) AddFile(filePath, content string) {
	o.ContentFS[filePath] = []byte(content)
}

// AddSchema adds all files from an fs.FS to the overlay at the given prefix.
func (o OverlayFS) AddSchema(pathPrefix string, schemaFS fs.FS) error {
	tempFS := fstest.MapFS{}

	err := fs.WalkDir(schemaFS, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		data, err := fs.ReadFile(schemaFS, p)
		if err != nil {
			return err
		}

		full := path.Join(pathPrefix, p)
		mapPath := strings.TrimPrefix(full, "/")
		tempFS[mapPath] = &fstest.MapFile{Data: data, Mode: fs.FileMode(0o600)}
		return nil
	})
	if err != nil {
		return err
	}

	return o.AddFilesystem("", tempFS)
}

// AddFilesystem adds all regular files from an fs.FS to the overlay.
func (o OverlayFS) AddFilesystem(pathPrefix string, sourceFS fs.FS) error {
	return fs.WalkDir(sourceFS, ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.Type().IsRegular() {
			return nil
		}

		f, err := sourceFS.Open(p)
		if err != nil {
			return err
		}
		defer f.Close()

		data, err := io.ReadAll(f)
		if err != nil {
			return err
		}

		full := path.Join(pathPrefix, p)
		if !strings.HasPrefix(full, "/") {
			full = "/" + full
		}
		o.ContentFS[full] = data
		return nil
	})
}

func (o OverlayFS) loadConfig() *load.Config {
	sources := make(map[string]load.Source)
	for p, data := range o.ContentFS {
		sources[p] = load.FromBytes(data)
	}
	return &load.Config{Overlay: sources, Dir: "/"}
}
