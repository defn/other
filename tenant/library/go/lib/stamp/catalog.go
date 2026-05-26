// Package stamp -- catalog.go provides shared helpers for CUE file manipulation.
//
// These helpers are the building blocks for all stamp types that mutate
// shared catalog files (mirrors.cue, versions.cue, apps.cue, catalog.cue, etc.).
// See AIDR-00045 for the design rationale.
package stamp

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ReadFile reads a file relative to rootDir.
func ReadFile(rootDir, path string) (string, error) {
	data, err := os.ReadFile(filepath.Join(rootDir, path))
	if err != nil {
		return "", fmt.Errorf("read %s: %w", path, err)
	}
	return string(data), nil
}

// WriteFile creates a new file relative to rootDir, creating directories as needed.
func WriteFile(rootDir, path, content string) error {
	fullPath := filepath.Join(rootDir, path)
	dir := filepath.Dir(fullPath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", dir, err)
	}
	if err := os.WriteFile(fullPath, []byte(content), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	fmt.Printf("  wrote %s\n", path)
	return nil
}

// UpdateFile overwrites an existing file relative to rootDir.
func UpdateFile(rootDir, path, content string) error {
	if err := os.WriteFile(filepath.Join(rootDir, path), []byte(content), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	fmt.Printf("  updated %s\n", path)
	return nil
}

// EntryExists checks if a key string appears in file content.
func EntryExists(content, key string) bool {
	return strings.Contains(content, key)
}

// InsertBeforeMarker inserts entry before the first matching marker string.
// Returns the modified content and true if a marker was found and insertion occurred.
func InsertBeforeMarker(content, entry string, markers []string) (string, bool) {
	for _, marker := range markers {
		idx := strings.Index(content, marker)
		if idx >= 0 {
			return content[:idx] + entry + content[idx:], true
		}
	}
	return content, false
}

// InsertBeforeLastBrace inserts entry before the final "}" in content.
// Returns the modified content and true if a closing brace was found.
func InsertBeforeLastBrace(content, entry string) (string, bool) {
	idx := strings.LastIndex(content, "}")
	if idx < 0 {
		return content, false
	}
	return content[:idx] + entry + content[idx:], true
}

// CueKey formats a CUE map key. Names with dashes are quoted.
func CueKey(name string) string {
	if strings.Contains(name, "-") {
		return fmt.Sprintf("%q", name)
	}
	return name
}

// CueIdent converts a name to a valid CUE identifier (dashes become underscores).
func CueIdent(name string) string {
	return strings.ReplaceAll(name, "-", "_")
}
