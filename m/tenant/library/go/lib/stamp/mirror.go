// Package stamp -- mirror.go surgically mutates mirror_images entries in
// catalog/mirrors.cue. The key, source, tag, and digest fields are updated
// atomically so the CUE key-parity invariant (see catalog/mirrors.cue's
// `_keyCheck: K & "\(source):\(tag)"` constraint) stays satisfied; any
// future drift would fail cue vet.
//
// History: this file replaces a Clojure regex step in
// .mise/tasks/upgrade.clj (step 7) that bumped mirror_images keys without
// bumping the inner tag+digest fields. The resulting key/tag skew made
// kustomize rewrites pin stale image tags until check-images caught the
// inconsistency 10+ pipeline steps later. The new shape has three
// properties the old one lacked:
//
//  1. Atomic rewrite -- the regex matches the FULL entry block
//     (key + source + tag + digest) and replaces the whole thing, so
//     partial drift is structurally impossible.
//  2. CUE invariant -- catalog/mirrors.cue's _keyCheck rejects any
//     drift at cue vet time with a precise "conflicting values" error
//     naming the entry; this is the belt to the primitive's suspenders.
//  3. Deterministic digest -- crane digest <source:newTag> resolves the
//     new digest in-band so the caller doesn't hand-carry it.
//
// Callers: BumpMirrorTagsFromKustomization is invoked by
// go/cmd/hatch/helmupgrade/service.go in Phase 0 of a helm upgrade,
// before the first hatch cycle, so the mirror catalog is already correct
// when gen re-renders kustomization.yaml and gen-app.cue from it.
package stamp

import (
	"errors"
	"fmt"
	"io/fs"
	"regexp"
)

// entryPattern returns the regex for a full mirror_images entry block
// matching source:tag. Indentation/shape are stable -- gen and appendMirrors
// produce the same layout -- so the pattern is fixed.
func entryPattern(source, tag string) string {
	esc := regexp.QuoteMeta
	return fmt.Sprintf(
		`(?m)"%s:%s":\s*\{\s*\n\s*source:\s*"%s"\s*\n\s*tag:\s*"%s"\s*\n\s*digest:\s*"[^"]*"\s*\n\s*\}`,
		esc(source), esc(tag), esc(source), esc(tag))
}

// BumpMirrorTag rewrites the mirror_images entry for `source` whose current
// tag matches `oldTag`, setting it to `newTag` and re-resolving the digest
// via `crane digest`. The entry's key, source, tag, and digest are rewritten
// atomically. If no entry matches, the call is a no-op (idempotent). Returns
// an error if crane fails or more than one entry matches.
//
// If a source:newTag entry already exists in the catalog (e.g. another app
// already pins this version), the orphan source:oldTag entry is deleted
// instead of rewritten -- otherwise the rewrite would produce two entries
// keyed source:newTag with potentially different digests, which CUE rejects
// at evaluation time. The existing source:newTag entry's digest is trusted;
// if it's stale, sync-mirrors will catch it on the next pass.
func BumpMirrorTag(rootDir, source, oldTag, newTag string) error {
	if oldTag == newTag {
		return nil
	}
	text, err := ReadFile(rootDir, "kernel/catalog/mirrors.cue")
	if err != nil {
		return err
	}

	re := regexp.MustCompile(entryPattern(source, oldTag))
	matches := re.FindAllStringIndex(text, -1)
	switch len(matches) {
	case 0:
		return nil
	case 1:
	default:
		return fmt.Errorf("mirrors.cue: %d entries match %s:%s", len(matches), source, oldTag)
	}

	// Destination already in catalog: delete the orphan entry rather than
	// rewriting it (which would create duplicate keys). Also strip an
	// optional trailing newline so we don't leave a blank gap.
	if regexp.MustCompile(entryPattern(source, newTag)).MatchString(text) {
		deleteRe := regexp.MustCompile(entryPattern(source, oldTag) + `\n?`)
		text = deleteRe.ReplaceAllString(text, "")
		if err := UpdateFile(rootDir, "kernel/catalog/mirrors.cue", text); err != nil {
			return err
		}
		fmt.Printf("  mirror %s: removed orphan %s (target %s already pinned)\n",
			source, oldTag, newTag)
		return nil
	}

	digest, err := sh(rootDir, "crane", "digest", source+":"+newTag)
	if err != nil {
		return fmt.Errorf("crane digest %s:%s: %w", source, newTag, err)
	}

	entry := fmt.Sprintf("\"%s:%s\": {\n\t\tsource: %q\n\t\ttag:    %q\n\t\tdigest: %q\n\t}",
		source, newTag, source, newTag, digest)
	text = text[:matches[0][0]] + entry + text[matches[0][1]:]
	if err := UpdateFile(rootDir, "kernel/catalog/mirrors.cue", text); err != nil {
		return err
	}
	fmt.Printf("  mirror %s: bumped %s -> %s (digest: %s...)\n",
		source, oldTag, newTag, digest[:19])
	return nil
}

// BumpMirrorTagsFromKustomization reads `var/app/<appName>/kustomization.yaml`,
// which the helm-upgrade task has already bumped with the new target tags,
// and bumps each matching mirror_images entry to align. Each image in the
// kustomization's `images:` list contributes (source, newTag); the old tag
// is discovered from the current mirror_images entry whose key begins with
// the source. Returns the number of entries bumped.
//
// AIDR-00146: kustomize apps render to var/app/<name>/, so kustomization.yaml
// lives there now (not the source dir).
//
// TODO: accept a tenant argument so defn-specific apps can upgrade too.
func BumpMirrorTagsFromKustomization(rootDir, appName string) (int, error) {
	kustPath := fmt.Sprintf("var/app/%s/kustomization.yaml", appName)
	kust, err := ReadFile(rootDir, kustPath)
	if err != nil {
		// Kustomize-only apps (e.g. arc-runners) don't render a chart and
		// therefore have no kustomization.yaml -- their image tags are
		// hand-coded in app.cue. Skip silently; the upgrade is purely a
		// version-tracking bump in versions.cue.
		if errors.Is(err, fs.ErrNotExist) {
			return 0, nil
		}
		return 0, err
	}
	mirrors, err := ReadFile(rootDir, "kernel/catalog/mirrors.cue")
	if err != nil {
		return 0, err
	}

	imageRe := regexp.MustCompile(
		`(?m)-\s+name:\s+(\S+)\s*\n\s+newName:\s+\S+\s*\n\s+newTag:\s+(\S+)`)

	bumped := 0
	for _, m := range imageRe.FindAllStringSubmatch(kust, -1) {
		source, newTag := m[1], m[2]
		oldTag, ok := findMirrorTag(mirrors, source)
		if !ok || oldTag == newTag {
			continue
		}
		if err := BumpMirrorTag(rootDir, source, oldTag, newTag); err != nil {
			return bumped, fmt.Errorf("bump %s: %w", source, err)
		}
		bumped++
		// Reload after each mutation so subsequent lookups reflect fresh state.
		mirrors, err = ReadFile(rootDir, "kernel/catalog/mirrors.cue")
		if err != nil {
			return bumped, err
		}
	}
	// BumpMirrorTag's orphan-deletion path (entryPattern + `\n?`) can leave a
	// blank line containing only a tab between adjacent entries; the next
	// hatch sync would fail mirrors_cue_fmt without this. Mirrors the post-
	// write cue fmt in helmapp.go's appendMirrors.
	if bumped > 0 {
		if _, err := sh(rootDir, "cue", "fmt", "kernel/catalog/mirrors.cue"); err != nil {
			return bumped, fmt.Errorf("cue fmt mirrors.cue: %w", err)
		}
	}
	return bumped, nil
}

// findMirrorTag returns the tag of the first mirror_images entry whose
// source equals `source` (by inspecting the `source:` field, not the key,
// so it is immune to key/tag drift). The second return is false if no
// matching entry exists.
func findMirrorTag(mirrors, source string) (string, bool) {
	esc := regexp.QuoteMeta
	pat := fmt.Sprintf(
		`(?m)source:\s*"%s"\s*\n\s*tag:\s*"([^"]*)"`, esc(source))
	m := regexp.MustCompile(pat).FindStringSubmatch(mirrors)
	if len(m) < 2 {
		return "", false
	}
	return m[1], true
}
