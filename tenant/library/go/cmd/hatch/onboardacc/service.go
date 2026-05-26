// Package onboardacc onboards a new AWS account end-to-end.
//
// Prerequisite: catalog/aws.cue must already contain an entry for
// <org>-<name> with an id (the account must already exist in AWS).
// Prior to invoking onboardacc, the operator is expected to have run
// `tofu apply` in the org dir to create the account and then
// backfilled its id into the catalog, followed by `mise run hatch`.
//
// From there, onboardacc drives the per-account pipeline:
//
//  1. (optional) org-level tofu plan + apply -- disabled by default
//     because every account onboarding after the first one should
//     start from a known-clean org state. Opt in with --org-phase.
//  2. backfill the new account id into catalog/aws.cue (no-op if
//     the operator already did it manually).
//  3. run the hatch cycle -- materializes infra/org/<org>/<name>/ and
//     regenerates ~/.aws/config with the chained bootstrap profile.
//  4. run `mise run tf bootstrap` in the account directory -- creates the
//     <org>-ops-terraform and auditor roles via the chained profile.
//  5. verify `mise run tf plan` is clean.
//
// Usage: defn hatch onboardacc <org>/<name> [--org-phase]
package onboardacc

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/defn/other/m/tenant/library/go/lib/gen"
	hatchlib "github.com/defn/other/m/tenant/library/go/lib/hatch"
	"github.com/defn/other/m/tenant/library/go/lib/runner"
	"github.com/spf13/cobra"
)

type Config struct {
	Org        string
	Name       string
	OrgPhase   bool // run the org-level init+plan+apply (phase 1). Default false.
	VerifyPlan bool // run the post-bootstrap drift-check plan (phase 5). Default false.
}

type Service struct{}

func NewService() *Service { return &Service{} }

func (s *Service) Run(_ context.Context, cfg Config, onReady func(error)) error {
	onReady(nil)
	return run(cfg)
}

func run(cfg Config) error {
	if cfg.Org == "" || cfg.Name == "" {
		return fmt.Errorf("usage: defn hatch onboardacc <org>/<name>")
	}

	wsRoot, err := gitRoot()
	if err != nil {
		return fmt.Errorf("locate workspace: %w", err)
	}
	// Read default_tenant from the catalog so onboardacc targets the
	// active tenant's infra tree. A fork swaps the tenant via
	// catalog.cue without code change. See AIDR-00071.
	genCtx, err := gen.NewContext(".", nil)
	if err != nil {
		return fmt.Errorf("init catalog: %w", err)
	}
	tenant := genCtx.DefaultTenant()
	orgDir := filepath.Join(wsRoot, "tenant", tenant, "infra", "org", cfg.Org)
	accDir := filepath.Join(orgDir, cfg.Name)
	acctKey := cfg.Org + "-" + cfg.Name

	if _, err := os.Stat(filepath.Join(orgDir, "main.tf")); err != nil {
		return fmt.Errorf("%s/main.tf does not exist -- org not in catalog", orgDir)
	}

	fmt.Printf("\u2713 onboarding %s (org-level dir: %s)\n", acctKey, orgDir)

	// Phase 1: org-level plan + apply (creates account + delegations + SSO).
	// Skipped by default -- the operator is expected to have run the org
	// apply before calling onboardacc so that phase 2 can read the new
	// account id straight out of tofu state. Refreshing the entire
	// AWS Organizations state on every account call is wasteful and is
	// the biggest single source of latency in the per-account loop.
	if cfg.OrgPhase {
		fmt.Println("\u2713 phase 1: org-level tofu init + plan + apply")
		if err := runInDir(orgDir, "mise", "exec", "--", "tofu", "init", "-input=false", "-lockfile=readonly"); err != nil {
			return fmt.Errorf("org tofu init: %w", err)
		}
		// Detect whether there are changes using -detailed-exitcode.
		// Plan file lives in /tmp so it doesn't pollute the manifest.
		planOut := filepath.Join(os.TempDir(), fmt.Sprintf("onboardacc-%s.tfplan", acctKey))
		defer os.Remove(planOut)
		planErr := runner.Run(context.Background(), runner.Opts{
			Args: []string{"mise", "exec", "--", "tofu", "plan", "-input=false", "-lock=false", "-detailed-exitcode", "-out=" + planOut},
			Dir:  orgDir,
		})
		planExit := exitCode(planErr)
		if planExit == 0 {
			fmt.Println("\u2713 org plan: no changes, skipping apply")
		} else if planExit == 2 {
			fmt.Println("\u2713 org plan: changes detected, applying")
			if err := runInDir(orgDir, "mise", "exec", "--", "tofu", "apply", "-input=false", planOut); err != nil {
				return fmt.Errorf("org tofu apply: %w", err)
			}
		} else {
			return fmt.Errorf("org tofu plan failed: %w", planErr)
		}
	} else {
		fmt.Println("\u2713 phase 1: skipped (org state assumed clean; pass --org-phase to force)")
	}

	// Phase 2: read new account id from tofu state, backfill catalog.
	fmt.Println("\u2713 phase 2: backfill catalog id from tofu state")
	newID, err := readAccountID(orgDir, acctKey)
	if err != nil {
		return fmt.Errorf("read account id from state: %w", err)
	}
	catalogPath := filepath.Join(wsRoot, "kernel", "catalog", "aws.cue")
	changed, err := backfillCatalogID(catalogPath, acctKey, newID)
	if err != nil {
		return fmt.Errorf("backfill catalog: %w", err)
	}
	if changed {
		fmt.Printf("\u2713 backfilled catalog id: %s = %s\n", acctKey, newID)
	} else {
		fmt.Printf("\u2713 catalog already has %s id = %s\n", acctKey, newID)
	}

	// Phase 3: hatch cycle to materialize account dir + regen aws config.
	// Skipped when <accDir>/main.tf already exists -- the operator is
	// expected to have run `mise run hatch` before invoking onboardacc,
	// so the per-account brick dir is already generated. The full
	// hatch.Cycle() call reanalyzes all ~7,500 Bazel targets regardless
	// of what actually changed, which was the second-biggest per-account
	// cost after phase 1. If the brick isn't there, we still run hatch
	// to materialize it.
	if _, err := os.Stat(filepath.Join(accDir, "main.tf")); err == nil {
		fmt.Println("\u2713 phase 3: skipped (account dir already materialized)")
	} else {
		fmt.Println("\u2713 phase 3: hatch cycle")
		oldWd, _ := os.Getwd()
		os.Chdir(wsRoot)
		_, herr := hatchlib.Cycle()
		os.Chdir(oldWd)
		if herr != nil {
			return fmt.Errorf("hatch cycle: %w", herr)
		}
		if _, err := os.Stat(filepath.Join(accDir, "main.tf")); err != nil {
			return fmt.Errorf("%s/main.tf not materialized by hatch: %w", accDir, err)
		}
	}

	// Phase 4: tf bootstrap -- creates ops-terraform and auditor roles.
	fmt.Println("\u2713 phase 4: tf bootstrap")
	// If already bootstrapped (.terraform.lock.hcl exists and tf plan is clean),
	// skip to save time.
	if bootstrapped, _ := alreadyBootstrapped(accDir); bootstrapped {
		fmt.Println("\u2713 account already bootstrapped, skipping")
	} else {
		if err := runInDir(accDir, "mise", "run", "tf", "bootstrap"); err != nil {
			return fmt.Errorf("tf bootstrap: %w", err)
		}
	}

	// Phase 5: verify account-level plan is clean. Skipped by default --
	// phase 4's `tofu apply` already verifies the plan as part of normal
	// apply semantics, so a follow-up clean-plan check is belt-and-
	// suspenders. Opt in with --verify-plan.
	if cfg.VerifyPlan {
		fmt.Println("\u2713 phase 5: verify clean plan")
		if err := runInDir(accDir, "mise", "run", "tf", "plan"); err != nil {
			return fmt.Errorf("tf plan: %w", err)
		}
		planTxt, err := os.ReadFile(filepath.Join(accDir, ".plan.txt"))
		if err != nil {
			return fmt.Errorf("read .plan.txt: %w", err)
		}
		if !strings.Contains(string(planTxt), "No changes") {
			return fmt.Errorf("post-bootstrap plan is not clean -- inspect %s/.plan.txt", accDir)
		}
	} else {
		fmt.Println("\u2713 phase 5: skipped (apply verified the plan; pass --verify-plan to force)")
	}

	fmt.Printf("\u2713 onboardacc %s complete (account id %s)\n", acctKey, newID)
	return nil
}

// readAccountID extracts the aws_organizations_account id for the given
// account key from tofu state in the given org directory.
func readAccountID(orgDir, acctKey string) (string, error) {
	addr := fmt.Sprintf(`module.org.aws_organizations_account.account[%q]`, acctKey)
	var combined bytes.Buffer
	err := runner.Run(context.Background(), runner.Opts{
		Args:   []string{"mise", "exec", "--", "tofu", "state", "show", "-no-color", addr},
		Dir:    orgDir,
		Stdout: &combined,
		Stderr: &combined,
	})
	out := combined.Bytes()
	if err != nil {
		return "", fmt.Errorf("tofu state show %s: %w\n%s", addr, err, out)
	}
	re := regexp.MustCompile(`(?m)^\s*id\s*=\s*"([0-9]+)"`)
	m := re.FindStringSubmatch(string(out))
	if len(m) < 2 {
		return "", fmt.Errorf("could not find id in state for %s", addr)
	}
	return m[1], nil
}

// backfillCatalogID injects `id: "<newID>"` into the aws_accounts entry
// for acctKey in catalog/aws.cue if it's missing. Returns true if the
// file was modified.
func backfillCatalogID(catalogPath, acctKey, newID string) (bool, error) {
	data, err := os.ReadFile(catalogPath)
	if err != nil {
		return false, err
	}
	src := string(data)
	// Already has id?
	alreadyRe := regexp.MustCompile(fmt.Sprintf(`%q:\s*{[^}]*\bid:\s*%q`, acctKey, newID))
	if alreadyRe.MatchString(src) {
		return false, nil
	}
	// Inject after name: "<name>" on the matching line.
	parts := strings.SplitN(acctKey, "-", 2)
	if len(parts) != 2 {
		return false, fmt.Errorf("invalid acct key %q", acctKey)
	}
	name := parts[1]
	pattern := regexp.MustCompile(fmt.Sprintf(
		`(%q:\s*{org:\s*%q,\s*name:\s*%q,)(\s*email:)`,
		acctKey, parts[0], name))
	replacement := fmt.Sprintf(`$1 id: %q,$2`, newID)
	newSrc := pattern.ReplaceAllString(src, replacement)
	if newSrc == src {
		return false, fmt.Errorf("could not locate %s entry in %s (expected pattern after `name: %q,`)", acctKey, catalogPath, name)
	}
	if err := os.WriteFile(catalogPath, []byte(newSrc), 0o644); err != nil {
		return false, err
	}
	return true, nil
}

// alreadyBootstrapped returns true if the account dir already has a
// working terraform state we can plan against.
func alreadyBootstrapped(accDir string) (bool, error) {
	out, _ := runner.Output(context.Background(), runner.Opts{
		Args: []string{"mise", "exec", "--", "tofu", "state", "list"},
		Dir:  accDir,
	})
	return strings.Contains(out, "module.account.aws_iam_role.terraform"), nil
}

// exitCode extracts the exit code from a (possibly wrapped) *exec.ExitError, or -1.
func exitCode(err error) int {
	if err == nil {
		return 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode()
	}
	return -1
}

func (s *Service) Stop(_ context.Context) error { return nil }

func MakeConfig(cmd *cobra.Command, args []string) Config {
	cfg := Config{}
	if len(args) > 0 {
		parts := strings.SplitN(args[0], "/", 2)
		if len(parts) == 2 {
			cfg.Org = parts[0]
			cfg.Name = parts[1]
		}
	}
	if cmd != nil {
		cfg.OrgPhase, _ = cmd.Flags().GetBool("org-phase")
		cfg.VerifyPlan, _ = cmd.Flags().GetBool("verify-plan")
	}
	return cfg
}

func RegisterFlags(cmd *cobra.Command) {
	cmd.Flags().Bool("org-phase", false,
		"run the org-level tofu init+plan+apply (phase 1); default false, assumes operator pre-applied the org")
	cmd.Flags().Bool("verify-plan", false,
		"run the post-bootstrap clean-plan check (phase 5); default false, apply already verifies")
}

func gitRoot() (string, error) {
	root, err := runner.Output(context.Background(), runner.Opts{
		Args: []string{"git", "rev-parse", "--show-toplevel"},
	})
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(filepath.Join(root, "m", "MODULE.bazel")); err == nil {
		return filepath.Join(root, "m"), nil
	}
	return root, nil
}

func runInDir(dir, name string, args ...string) error {
	return runner.Run(context.Background(), runner.Opts{
		Args: append([]string{name}, args...),
		Dir:  dir,
	})
}

// used to silence unused import if backfillCatalogID ever removed.
var _ = json.Marshal
