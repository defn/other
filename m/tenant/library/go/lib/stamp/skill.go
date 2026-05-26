// Skill Midas: register a Claude Code skill instance.
//
// A skill brick lives at root/skills/sp-<name>/ and consists of a
// hand-edited SKILL.md plus optional helper subdirs (scripts,
// references, prompts, examples). The catalog entry in
// kernel/catalog/skills.cue carries instance metadata; per-instance
// brick registration goes through StampBrick.

package stamp

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var skillNameRE = regexp.MustCompile(`^sp-[a-z][a-z0-9-]*$`)

var skillSubdirAllowed = map[string]bool{
	"scripts":    true,
	"references": true,
	"prompts":    true,
	"examples":   true,
}

type skillEntry struct {
	desc    string
	path    string
	subdirs []string
}

// StampSkill registers a skill instance:
//
//  1. Append entry to kernel/catalog/skills.cue (idempotent).
//  2. Register the per-instance brick via StampBrick (writes
//     kernel/catalog/brick-root--skills--<name>.cue).
//  3. Scaffold root/skills/<name>/SKILL.md if it doesn't exist
//     (preserves any hand-edited body on re-stamp).
//
// Subdir BUILD.bazel files are emitted by the skill generator on
// `defn hatch`; this stamp does not touch them.
func StampSkill(rootDir, name, desc string, subdirs []string) error {
	if !skillNameRE.MatchString(name) {
		return fmt.Errorf("skill name %q must match ^sp-[a-z][a-z0-9-]*$", name)
	}
	if desc == "" {
		return fmt.Errorf("--desc is required for `defn stamp skill`")
	}

	for _, sd := range subdirs {
		if !skillSubdirAllowed[sd] {
			return fmt.Errorf("subdir %q not in {scripts, references, prompts, examples}", sd)
		}
	}
	sort.Strings(subdirs)

	brickPath := "root/skills/" + name

	if err := upsertSkillCatalog(rootDir, name, desc, brickPath, subdirs); err != nil {
		return err
	}

	if err := StampBrick(rootDir, "skill", brickPath, desc); err != nil {
		return err
	}

	if err := scaffoldSkillMD(rootDir, brickPath, name, desc); err != nil {
		return err
	}

	for _, sd := range subdirs {
		if err := os.MkdirAll(filepath.Join(rootDir, brickPath, sd), 0o755); err != nil {
			return fmt.Errorf("mkdir %s/%s: %w", brickPath, sd, err)
		}
	}

	return nil
}

// upsertSkillCatalog rewrites kernel/catalog/skills.cue to include
// the requested entry. Existing entries are preserved as-is unless
// their name matches the requested entry, in which case description
// and subdirs are updated.
func upsertSkillCatalog(rootDir, name, desc, brickPath string, subdirs []string) error {
	catFile := filepath.Join(rootDir, "kernel", "catalog", "skills.cue")

	merged, err := parseSkillCatalog(catFile)
	if err != nil {
		return err
	}
	merged[name] = skillEntry{desc: desc, path: brickPath, subdirs: subdirs}

	keys := make([]string, 0, len(merged))
	for k := range merged {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	b.WriteString(`@experiment(aliasv2,explicitopen,shortcircuit,try)

// Schema constraints for the skill Midas. Skill instances live as
// bricks under m/root/skills/sp-<name>/; instance metadata is added
// here (or in a tenant overlay) by ` + "`defn stamp skill`" + `.
package catalog

import "github.com/defn/other/kernel/schema"

// Per-skill schema in kernel/schema/skill.cue.
//
// The skills map is keyed by skill name; the key == #Skill.name
// invariant is enforced by ` + "`defn stamp skill`" + `, not by the schema.
skills: [string]: schema.#Skill

skills: {
`)
	for _, k := range keys {
		e := merged[k]
		b.WriteString(fmt.Sprintf("\t%q: {\n", k))
		b.WriteString(fmt.Sprintf("\t\tname:        %q\n", k))
		b.WriteString(fmt.Sprintf("\t\tdescription: %q\n", e.desc))
		b.WriteString(fmt.Sprintf("\t\tpath:        %q\n", e.path))
		if len(e.subdirs) > 0 {
			parts := make([]string, len(e.subdirs))
			for i, s := range e.subdirs {
				parts[i] = fmt.Sprintf("%q", s)
			}
			b.WriteString(fmt.Sprintf("\t\tsubdirs:     [%s]\n", strings.Join(parts, ", ")))
		}
		b.WriteString("\t}\n")
	}
	b.WriteString("}\n")

	if cur, err := os.ReadFile(catFile); err == nil && string(cur) == b.String() {
		return nil
	}
	return os.WriteFile(catFile, []byte(b.String()), 0o644)
}

// parseSkillCatalog extracts existing entries via lightweight regex.
// CUE round-tripping with comments is fragile; the catalog is small
// and machine-managed, so a textual rewrite is fine. An empty/missing
// file yields an empty map.
func parseSkillCatalog(path string) (map[string]skillEntry, error) {
	out := map[string]skillEntry{}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return out, nil
		}
		return nil, fmt.Errorf("read %s: %w", path, err)
	}

	entryRE := regexp.MustCompile(`(?m)^\s*"(sp-[a-z0-9-]+)":\s*\{`)
	descRE := regexp.MustCompile(`(?m)^\s*description:\s*"([^"]*)"`)
	pathRE := regexp.MustCompile(`(?m)^\s*path:\s*"([^"]*)"`)
	subRE := regexp.MustCompile(`(?m)^\s*subdirs:\s*\[([^\]]*)\]`)
	itemRE := regexp.MustCompile(`"([a-z]+)"`)

	indices := entryRE.FindAllSubmatchIndex(data, -1)
	for i, idx := range indices {
		start := idx[1]
		end := len(data)
		if i+1 < len(indices) {
			end = indices[i+1][0]
		}
		block := data[start:end]
		key := string(data[idx[2]:idx[3]])

		e := skillEntry{}
		if m := descRE.FindSubmatch(block); m != nil {
			e.desc = string(m[1])
		}
		if m := pathRE.FindSubmatch(block); m != nil {
			e.path = string(m[1])
		}
		if m := subRE.FindSubmatch(block); m != nil {
			items := itemRE.FindAllSubmatch(m[1], -1)
			for _, it := range items {
				e.subdirs = append(e.subdirs, string(it[1]))
			}
		}
		out[key] = e
	}
	return out, nil
}

func scaffoldSkillMD(rootDir, brickPath, name, desc string) error {
	full := filepath.Join(rootDir, brickPath, "SKILL.md")
	if _, err := os.Stat(full); err == nil {
		fmt.Printf("preserved: %s/SKILL.md already exists\n", brickPath)
		return nil
	}

	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", brickPath, err)
	}

	body := fmt.Sprintf(`---
name: %s
description: %s
---

# %s

## Overview

TODO -- describe what this skill does and when to use it.
`, name, desc, name)

	if err := os.WriteFile(full, []byte(body), 0o644); err != nil {
		return fmt.Errorf("write %s/SKILL.md: %w", brickPath, err)
	}
	fmt.Printf("created: %s/SKILL.md\n", brickPath)
	return nil
}
