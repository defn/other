// Package brickpkg derives the CUE package name to use when a brick's
// source dir hosts a `dispatch.cue` (AIDR-00132 OQ7) or any other
// per-brick CUE file, and exposes the cue.mod skip rule that goes
// hand-in-hand with that derivation.
//
// The detection logic must be a single source of truth so that the
// dispatchworker generator (m/go/lib/gen/dispatchworker) and the
// stamp pipeline (m/go/lib/stamp/stamp.go) agree on the package
// name a brick's catalog entry imports. Two subproblems are folded in:
//
//	A. Bricks that already host CUE files must reuse the existing
//	   dir-local package; CUE forbids two packages in one dir.
//	   DetectPackage parses the first non-dispatch.cue file in the
//	   dir for `package <name>`.
//
//	B. Bricks without any .cue files need a stub package name.
//	   StubPackageName derives one from the path's last segment,
//	   sanitized to a valid CUE identifier `[a-zA-Z_][a-zA-Z_0-9]*`
//	   (leading dots dropped, other non-identifier characters
//	   collapsed to `_`). Collisions between unrelated bricks are
//	   harmless because CUE package names are dir-scoped.
package brickpkg

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// DispatchFile is the canonical filename written into each brick dir
// by the dispatchworker generator. Detection ignores it so the stub
// fallback stays stable across repeated runs (the only .cue file in
// the dir would otherwise be the dispatchworker's own output).
const DispatchFile = "dispatch.cue"

// pkgRe matches `package <ident>` at start-of-line. Tolerant of
// leading whitespace because CUE permits indented package decls.
var pkgRe = regexp.MustCompile(`(?m)^\s*package\s+([A-Za-z_][A-Za-z_0-9]*)`)

// DetectPackage returns the CUE package name to use for a per-brick
// CUE file at brickDir. Subproblem A: read the first existing .cue
// file's package decl. Subproblem B: stub-derive from the path's
// last segment when no .cue files are present.
//
// dispatch.cue is treated as a side-output: if it's the only .cue
// file in the dir, it's ignored and the stub fallback runs. That
// makes detection idempotent across hatch passes.
func DetectPackage(brickDir, brickPath string) (string, error) {
	cues, err := filepath.Glob(filepath.Join(brickDir, "*.cue"))
	if err != nil {
		return "", err
	}
	for _, c := range cues {
		if filepath.Base(c) == DispatchFile {
			continue
		}
		data, err := os.ReadFile(c)
		if err != nil {
			return "", fmt.Errorf("read %s: %w", c, err)
		}
		if m := pkgRe.FindSubmatch(data); m != nil {
			return string(m[1]), nil
		}
	}
	return StubPackageName(brickPath), nil
}

// StubPackageName derives a valid CUE package name from a brick path.
// Rules:
//   - Last path segment.
//   - Leading dots dropped (so `.devcontainer` -> `devcontainer`).
//   - Characters outside `[a-zA-Z_0-9]` collapsed to `_`.
//   - If the result starts with a digit (or is empty after
//     sanitization), an `_` is prepended so the identifier is valid.
func StubPackageName(brickPath string) string {
	base := filepath.Base(brickPath)
	base = strings.TrimLeft(base, ".")
	if base == "" {
		base = "stub"
	}
	var sb strings.Builder
	for _, r := range base {
		switch {
		case r >= 'a' && r <= 'z',
			r >= 'A' && r <= 'Z',
			r == '_',
			r >= '0' && r <= '9':
			sb.WriteRune(r)
		default:
			sb.WriteRune('_')
		}
	}
	s := sb.String()
	if s == "" {
		return "stub"
	}
	if s[0] >= '0' && s[0] <= '9' {
		return "_" + s
	}
	return s
}

// IsCueModPath reports whether p is the cue.mod dir or anything
// nested inside it. CUE forbids packages inside cue.mod/, so a
// dispatch.cue (or any other per-brick CUE file imported by the
// catalog) cannot live there.
func IsCueModPath(p string) bool {
	return p == "cue.mod" || strings.HasPrefix(p, "cue.mod/")
}

// readsRe / writesRe match the `reads:` / `writes:` line inside
// a worker block. The list literal may be empty (`[]`), single-
// line (`["foo", "bar"]`), or multi-line; bracket balancing in
// extractList handles all three.
var readsRe = regexp.MustCompile(`(?m)^\s*reads:\s*\[`)
var writesRe = regexp.MustCompile(`(?m)^\s*writes:\s*\[`)

// ReadWorkerIO reads <brickDir>/dispatch.cue, extracts the worker's
// reads and writes lists, and returns them as Go []string.
//
//   - If dispatch.cue does not exist, returns (nil, nil, false, nil)
//     -- the brick has no on-disk worker (root branch, app branch,
//     cue.mod, freshly stamped brick before the first hatch).
//
//   - If dispatch.cue exists but its worker block doesn't match the
//     expected `reads: [...]` / `writes: [...]` shape, returns an
//     error rather than silently substituting empty lists.
//
// AIDR-00136: this is the bridge between dispatchworker's per-brick
// worker file and the catalog's inlined `reads:` / `writes:` fields.
// `restamp` calls this for each brick with `stamp_type` so the
// catalog mirrors whatever the user has put in worker.reads /
// worker.writes; the gen pipeline propagates dispatch.cue edits
// into the catalog at every hatch.
func ReadWorkerIO(brickDir string) (reads, writes []string, ok bool, err error) {
	path := filepath.Join(brickDir, DispatchFile)
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, false, nil
		}
		return nil, nil, false, fmt.Errorf("read %s: %w", path, err)
	}

	reads, err = extractList(data, readsRe, "reads")
	if err != nil {
		return nil, nil, false, fmt.Errorf("%s: %w", path, err)
	}
	writes, err = extractList(data, writesRe, "writes")
	if err != nil {
		return nil, nil, false, fmt.Errorf("%s: %w", path, err)
	}
	return reads, writes, true, nil
}

// extractList finds the named field's list literal in a worker
// block and parses its string elements. Tolerates trailing commas,
// inline comments, and multi-line lists by balancing brackets.
func extractList(data []byte, fieldRe *regexp.Regexp, name string) ([]string, error) {
	loc := fieldRe.FindIndex(data)
	if loc == nil {
		return nil, fmt.Errorf("worker.%s field not found", name)
	}
	// loc[1] points just past `[`. Walk forward, balancing brackets
	// and respecting double-quoted strings (which may contain `[`/
	// `]` for path globs etc.).
	body, err := captureUntilClose(data[loc[1]:])
	if err != nil {
		return nil, fmt.Errorf("worker.%s: %w", name, err)
	}
	return parseStringList(body)
}

// captureUntilClose returns the bytes between the opening `[` (just
// before src) and its matching `]`. Tracks nesting depth and
// double-quoted strings.
func captureUntilClose(src []byte) ([]byte, error) {
	depth := 1
	inStr := false
	for i := 0; i < len(src); i++ {
		c := src[i]
		if inStr {
			switch c {
			case '\\':
				i++ // skip escaped char
			case '"':
				inStr = false
			}
			continue
		}
		switch c {
		case '"':
			inStr = true
		case '[':
			depth++
		case ']':
			depth--
			if depth == 0 {
				return src[:i], nil
			}
		}
	}
	return nil, fmt.Errorf("unterminated list")
}

// parseStringList parses the body of a CUE list literal into Go
// strings. Tolerates whitespace, trailing commas, line comments
// (`// ...`), and multi-line layouts. Each list element must be a
// double-quoted string; non-string elements (numbers, references)
// are not supported because worker.reads / worker.writes are
// always [...string].
func parseStringList(src []byte) ([]string, error) {
	var out []string
	i := 0
	for i < len(src) {
		// Skip whitespace and commas.
		for i < len(src) && (src[i] == ' ' || src[i] == '\t' || src[i] == '\n' || src[i] == '\r' || src[i] == ',') {
			i++
		}
		// Skip line comments.
		if i+1 < len(src) && src[i] == '/' && src[i+1] == '/' {
			for i < len(src) && src[i] != '\n' {
				i++
			}
			continue
		}
		if i >= len(src) {
			break
		}
		if src[i] != '"' {
			return nil, fmt.Errorf("unexpected character %q at offset %d (expected string element)", src[i], i)
		}
		i++ // past opening "
		start := i
		for i < len(src) && src[i] != '"' {
			if src[i] == '\\' {
				i += 2
				continue
			}
			i++
		}
		if i >= len(src) {
			return nil, fmt.Errorf("unterminated string element")
		}
		out = append(out, string(src[start:i]))
		i++ // past closing "
	}
	return out, nil
}
