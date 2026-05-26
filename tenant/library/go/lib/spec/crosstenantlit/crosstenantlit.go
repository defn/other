// Package crosstenantlit implements SPEC-00352, the cross-tenant
// literal vet introduced by AIDR-00102.
//
// For every leaf tenant T (a tenant whose directory contains
// catalog/auth.cue), no source file under tenant/T/ may contain a
// string literal naming any other leaf tenant or any other leaf
// tenant's declared auth profile values. Library tenants (no
// auth.cue) are referenceable by all -- this is the intentional
// federation direction in the GRAFT whitepaper. Self-references
// inside T's own tree are allowed; the catalog-borrow declaration
// at tenant/T/catalog/auth.cue is the one place T may name another
// tenant's profile.
//
// SPEC-00352 is the tenant-side complement of SPEC-00351 (which
// guards the kernel/ substrate). After AIDR-00101 routed every
// "defn-org" hardcode through auth.{tofu,oci}, this vet prevents a
// future tenant from silently re-introducing the coupling AIDR-00101
// removed.
//
// Check is catalog-pure: callers materialize the tenant
// classification, profile values, source files, and generator-write
// union, then call Check. The CLI wrapper at //go/cmd/check/crosstenantlit
// performs the materialization (CUE eval for brick_io.writes,
// filesystem walk for tenants and source files).
package crosstenantlit

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// Tenant is the minimal projection of one tenant for the vet.
// IsLeaf is true when the tenant declares catalog/auth.cue. Profiles
// is the deduped, ordered list of profile values declared in
// tenant/Name/catalog/auth.cue (auth.tofu, auth.oci, ...). A
// non-leaf tenant contributes no forbidden literals.
type Tenant struct {
	Name     string   `json:"name"`
	Path     string   `json:"path"`
	IsLeaf   bool     `json:"is_leaf"`
	Profiles []string `json:"profiles,omitempty"`
}

// SourceFile is one tenant-owned file already loaded into memory.
// Tenant names the owning leaf tenant directory (the immediate child
// of tenant/ that contains the file).
type SourceFile struct {
	Path    string `json:"path"`
	Tenant  string `json:"tenant"`
	Content string `json:"content"`
}

// Violation names a single forbidden-literal occurrence.
// OwnerKind is "name" (the tenant directory name) or "profile" (an
// auth.* value declared by the owning tenant).
type Violation struct {
	Path        string `json:"path"`
	Line        int    `json:"line"`
	Literal     string `json:"literal"`
	OwnerTenant string `json:"owner_tenant"`
	OwnerKind   string `json:"owner_kind"`
}

// Format renders one Violation as a single-line message in the
// AIDR-00102 failure shape: file:line + matched literal + owner +
// canonical fix + the discovered leaf set.
func (v Violation) Format(allLeafs []string) string {
	return fmt.Sprintf(
		"SPEC-00352: %s:%d contains forbidden literal %q (owned by tenant %q, kind=%s); declare it in the offending tenant's catalog/auth.cue and let the generator stamp it in. Discovered leaf tenants: %s.",
		v.Path, v.Line, v.Literal, v.OwnerTenant, v.OwnerKind, strings.Join(allLeafs, ", "),
	)
}

var commentRE = regexp.MustCompile(`^[ \t]*(//|#|;;)`)

// Check returns the sorted list of violations across all source
// files. Sort key is (Path, Line, Literal).
//
// Allowed exceptions (skipped before regex match):
//   - The catalog-borrow declaration at tenant/T/catalog/auth.cue --
//     this is the one place T may name another tenant's profile.
//   - Generator-output paths -- any file whose path is in genWrites
//     is a derivation of catalog state, not a hardcode.
//   - Comment lines (leading whitespace + // | # | ;;), mirroring
//     SPEC-00351's comment skip.
//
// Library tenants (IsLeaf == false) own no forbidden literals and
// receive no scan.
func Check(tenants []Tenant, files []SourceFile, genWrites map[string]bool) []Violation {
	var leafs []Tenant
	leafByName := map[string]Tenant{}
	for _, t := range tenants {
		if t.IsLeaf {
			leafs = append(leafs, t)
			leafByName[t.Name] = t
		}
	}
	sort.Slice(leafs, func(i, j int) bool { return leafs[i].Name < leafs[j].Name })

	type owner struct {
		tenant string
		kind   string
	}
	type forbidden struct {
		re     *regexp.Regexp
		attrib map[string]owner
	}
	forbidByTenant := map[string]forbidden{}
	for _, T := range leafs {
		ownProfiles := map[string]bool{}
		for _, p := range T.Profiles {
			ownProfiles[p] = true
		}
		attrib := map[string]owner{}
		for _, Tp := range leafs {
			if Tp.Name == T.Name {
				continue
			}
			attrib[fmt.Sprintf("tenant/%s", Tp.Name)] = owner{Tp.Name, "name"}
			attrib[Tp.Name] = owner{Tp.Name, "name"}
			for _, p := range Tp.Profiles {
				if ownProfiles[p] {
					continue
				}
				if _, taken := attrib[p]; taken {
					continue
				}
				attrib[p] = owner{Tp.Name, "profile"}
			}
		}
		if len(attrib) == 0 {
			forbidByTenant[T.Name] = forbidden{}
			continue
		}
		keys := make([]string, 0, len(attrib))
		for k := range attrib {
			keys = append(keys, k)
		}
		sort.Slice(keys, func(i, j int) bool {
			if len(keys[i]) != len(keys[j]) {
				return len(keys[i]) > len(keys[j])
			}
			return keys[i] < keys[j]
		})
		parts := make([]string, len(keys))
		for i, k := range keys {
			parts[i] = regexp.QuoteMeta(k)
		}
		alt := strings.Join(parts, "|")
		// Three quote forms covered: "X" (CUE/Go/JSON/TOML basic),
		// 'X' (TOML literal-string -- realistic in mise.toml /
		// terraform.tfvars), and `X` (Go raw / CUE backtick label).
		// CUE triple-quoted heredocs are not handled here; per-line
		// regex would split awkwardly. AIDR-00103 records the gap.
		re := regexp.MustCompile(`"(` + alt + `)"|'(` + alt + `)'|` + "`(" + alt + ")`")
		forbidByTenant[T.Name] = forbidden{re: re, attrib: attrib}
	}

	var out []Violation
	for _, f := range files {
		T, ok := leafByName[f.Tenant]
		if !ok {
			continue
		}
		if f.Path == fmt.Sprintf("tenant/%s/catalog/auth.cue", T.Name) {
			continue
		}
		if genWrites[f.Path] {
			continue
		}
		forb := forbidByTenant[T.Name]
		if forb.re == nil {
			continue
		}
		for i, line := range strings.Split(f.Content, "\n") {
			if commentRE.MatchString(line) {
				continue
			}
			for _, m := range forb.re.FindAllStringSubmatch(line, -1) {
				// Three capture groups, one per quote form; the
				// non-empty one is the match.
				lit := m[1]
				if lit == "" {
					lit = m[2]
				}
				if lit == "" {
					lit = m[3]
				}
				ow := forb.attrib[lit]
				out = append(out, Violation{
					Path:        f.Path,
					Line:        i + 1,
					Literal:     lit,
					OwnerTenant: ow.tenant,
					OwnerKind:   ow.kind,
				})
			}
		}
	}

	sort.Slice(out, func(i, j int) bool {
		if out[i].Path != out[j].Path {
			return out[i].Path < out[j].Path
		}
		if out[i].Line != out[j].Line {
			return out[i].Line < out[j].Line
		}
		return out[i].Literal < out[j].Literal
	})
	return out
}

// LeafNames returns the alphabetically-sorted leaf tenant names from
// a tenant set. Useful for embedding the discovered set in the
// failure message per AIDR-00102.
func LeafNames(tenants []Tenant) []string {
	var names []string
	for _, t := range tenants {
		if t.IsLeaf {
			names = append(names, t.Name)
		}
	}
	sort.Strings(names)
	return names
}
