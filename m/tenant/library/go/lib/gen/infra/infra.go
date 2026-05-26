// Package infra generates AWS infrastructure directory tree from the catalog.
package infra

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"github.com/defn/other/m/tenant/library/go/lib/gen"
	"github.com/defn/other/m/tenant/library/go/lib/gen/golib"
)

const awsTemplate = "kernel/interface/aws/templates.cue"

type accInfo struct {
	key                  string
	name                 string
	org                  string
	id                   string
	email                string
	iamBill              string
	roleName             string
	delegatedSP          []string
	importedDelegSP      []string
	outboundFed          bool
	parentOU             string
	cloudtrailBucketHost bool
	pubBucketHost        bool
}

type orgInfo struct {
	key           string
	name          string
	ssoRegion     string
	pubPriceClass string
}

// Run generates the infra directory tree from AWS catalog data.
func Run(ctx *gen.Context) error {
	// Tenant-rooted output paths: every "tenant/<owner>/infra/..."
	// site reads from this single value. Defaults to "defn"; a kernel
	// fork swaps it via catalog.cue's default_tenant field. See
	// AIDR-00071 (kernel/tenant decoupling).
	tenant := ctx.DefaultTenant()
	infraBase := "tenant/" + tenant + "/infra"

	orgs := ctx.CatalogQuery("aws_orgs")
	accounts := ctx.CatalogQuery("aws_accounts")
	state := ctx.CatalogQuery("aws_state")

	stateAccountID, _ := gen.DecodeString(state, "account_id")
	stateBucket, _ := gen.DecodeString(state, "bucket")
	stateRegion, _ := gen.DecodeString(state, "region")
	// Master AWS profile lives in the tenant overlay's auth.tofu;
	// AIDR-00101 split this off from aws_state.profile so the profile
	// name flows from a dedicated catalog slot. Every per-account /
	// per-org main.tf and mise.toml under tenant/<t>/infra/ embeds
	// this value, including the embedded backend "profile" string,
	// the per-region provider blocks, and the chained-SSO source
	// profile in mise.toml.
	stateProfile, _ := gen.DecodeString(ctx.CatalogQuery("auth"), "tofu")

	// Global region policy lists -- single source of truth for both
	// the RegionAllowlist SCP and the per-account opt-in disables.
	var allowedRegions, forbiddenRegions []string
	gen.IterList(ctx.CatalogQuery("aws_allowed_regions"), func(v cue.Value) error {
		if s, err := v.String(); err == nil {
			allowedRegions = append(allowedRegions, s)
		}
		return nil
	})
	gen.IterList(ctx.CatalogQuery("aws_forbidden_regions"), func(v cue.Value) error {
		if s, err := v.String(); err == nil {
			forbiddenRegions = append(forbiddenRegions, s)
		}
		return nil
	})
	allowedRegionsHCL := hclStringList(allowedRegions)
	forbiddenRegionsHCL := hclStringList(forbiddenRegions)

	// Per-region provider plumbing for module/aws-account hardening
	// resources. The module declares one configuration_alias per
	// allowed region (region_<r_underscored>) plus one EBS encryption
	// default + one default SG strip per alias. Both ends read from
	// aws_allowed_regions so they cannot drift.
	if err := stampAccountRegionsTf(ctx, allowedRegions); err != nil {
		return err
	}
	perRegionProviderMap := buildPerRegionProviderMap(allowedRegions)

	stateTags := map[string]string{
		"state_profile":           stateProfile,
		"state_account_id":        stateAccountID,
		"state_bucket":            stateBucket,
		"state_region":            stateRegion,
		"allowed_regions_hcl":     allowedRegionsHCL,
		"forbidden_regions_hcl":   forbiddenRegionsHCL,
		"per_region_provider_map": perRegionProviderMap,
	}

	// Build accounts by org
	var allAccs []accInfo
	gen.IterMap(accounts, func(key string, v cue.Value) error {
		ai := accInfo{key: gen.CueFieldKey(key)}
		ai.name, _ = gen.DecodeString(v, "name")
		ai.org, _ = gen.DecodeString(v, "org")
		ai.id, _ = gen.DecodeString(v, "id")
		ai.email, _ = gen.DecodeString(v, "email")
		ai.iamBill = gen.DecodeStringOr(v, "iam_user_access_to_billing", "")
		ai.roleName = gen.DecodeStringOr(v, "role_name", "")
		if dsv := v.LookupPath(cue.ParsePath("delegated_services")); dsv.Exists() {
			gen.IterList(dsv, func(elem cue.Value) error {
				if s, err := elem.String(); err == nil {
					ai.delegatedSP = append(ai.delegatedSP, s)
				}
				return nil
			})
		}
		if idv := v.LookupPath(cue.ParsePath("imported_delegated_services")); idv.Exists() {
			gen.IterList(idv, func(elem cue.Value) error {
				if s, err := elem.String(); err == nil {
					ai.importedDelegSP = append(ai.importedDelegSP, s)
				}
				return nil
			})
		}
		if ofv := v.LookupPath(cue.ParsePath("outbound_federation")); ofv.Exists() {
			if b, err := ofv.Bool(); err == nil {
				ai.outboundFed = b
			}
		}
		if cbh := v.LookupPath(cue.ParsePath("cloudtrail_bucket_host")); cbh.Exists() {
			if b, err := cbh.Bool(); err == nil {
				ai.cloudtrailBucketHost = b
			}
		}
		if pbh := v.LookupPath(cue.ParsePath("pub_bucket_host")); pbh.Exists() {
			if b, err := pbh.Bool(); err == nil {
				ai.pubBucketHost = b
			}
		}
		ai.parentOU = gen.DecodeStringOr(v, "parent_ou", "")
		allAccs = append(allAccs, ai)
		return nil
	})
	sort.Slice(allAccs, func(i, j int) bool { return allAccs[i].key < allAccs[j].key })

	byOrg := map[string][]accInfo{}
	for _, a := range allAccs {
		byOrg[a.org] = append(byOrg[a.org], a)
	}

	// Parent BUILD.bazel files
	ctx.StampFromCUE(awsTemplate, infraBase, map[string]string{},
		[]gen.StampFile{{Field: "parent_build_bazel", Filename: "BUILD.bazel"}})
	ctx.StampFromCUE(awsTemplate, infraBase+"/org", map[string]string{},
		[]gen.StampFile{{Field: "bare_build_bazel", Filename: "BUILD.bazel"}})

	// infra/global/ -- cross-account S3 buckets
	// Skip accounts with no id yet (not created by tofu apply)
	var providerEntries strings.Builder
	for _, acc := range allAccs {
		if acc.id == "" {
			continue
		}
		fmt.Fprintf(&providerEntries, "\nprovider \"aws\" {\n  profile = \"%s\"\n  region  = \"%s\"\n  alias   = \"%s\"\n  assume_role {\n    role_arn = \"arn:aws:iam::%s:role/%s-ops-terraform\"\n  }\n}\n\nmodule \"s3-%s\" {\n  acl = \"private\"\n  attributes = [\n    \"%s\",\n  ]\n  enabled            = true\n  name               = \"global\"\n  namespace          = \"dfn\"\n  stage              = \"defn\"\n  user_enabled       = false\n  versioning_enabled = false\n  source             = \"../../../../vendor/terraform-aws-s3-bucket\"\n  providers = {\n    aws = aws.%s\n  }\n}\n",
			stateProfile, stateRegion, acc.key, acc.id, acc.org, acc.key, acc.key, acc.key)
	}

	globalTags := mergeMaps(stateTags, map[string]string{
		"provider_entries": providerEntries.String(),
		"profile":          stateProfile,
		"region":           stateRegion,
		"has_lock":         hasLock(ctx, infraBase+"/global"),
	})
	ctx.StampFromCUE(awsTemplate, infraBase+"/global", globalTags,
		[]gen.StampFile{
			{Field: "global_main_tf", Filename: "main.tf"},
			{Field: "mise_toml", Filename: "mise.toml"},
			{Field: "component_build_bazel", Filename: "BUILD.bazel"},
		})
	ctx.LogOK("generated infra/global/")

	// Per-org and per-account directories
	var orgEntries []orgInfo
	gen.IterMap(orgs, func(key string, v cue.Value) error {
		name, _ := gen.DecodeString(v, "name")
		ssoRegion := gen.DecodeStringOr(v, "sso_region", stateRegion)
		pubPriceClass := gen.DecodeStringOr(v, "pub_price_class", "")
		orgEntries = append(orgEntries, orgInfo{key: key, name: name, ssoRegion: ssoRegion, pubPriceClass: pubPriceClass})
		return nil
	})
	sort.Slice(orgEntries, func(i, j int) bool { return orgEntries[i].key < orgEntries[j].key })

	// Parallelize per-org generation
	if err := gen.ParallelN(8, len(orgEntries), func(idx int) error {
		oe := orgEntries[idx]
		orgName := oe.name
		ssoRegion := oe.ssoRegion
		pubPriceClass := oe.pubPriceClass
		orgDir := infraBase + "/org/" + orgName
		orgAccs := byOrg[orgName]

		// Find org management account ID
		var orgAccID string
		for _, a := range orgAccs {
			if a.name == "org" {
				orgAccID = a.id
				break
			}
		}

		// CloudTrail per-org metadata. The host account is the one with
		// cloudtrail_bucket_host: true. The ops account is the one with
		// non-empty delegated_services (same heuristic module/aws-org's
		// resource-policy uses). Both must be resolved with non-empty ids
		// before we flip cloudtrail_enabled on -- otherwise gen runs
		// before the new -log account exists would emit a broken trail.
		var ctHostAcc, ctOpsAcc *accInfo
		for i := range orgAccs {
			if orgAccs[i].cloudtrailBucketHost && ctHostAcc == nil {
				ctHostAcc = &orgAccs[i]
			}
			if len(orgAccs[i].delegatedSP) > 0 && ctOpsAcc == nil {
				ctOpsAcc = &orgAccs[i]
			}
		}
		ctTrailName := orgName + "-org-trail"
		ctEnabled := "false"
		ctBucketName := ""
		ctAliasArn := ""
		ctOpsId := ""
		if ctHostAcc != nil && ctHostAcc.id != "" && ctOpsAcc != nil && ctOpsAcc.id != "" {
			ctEnabled = "true"
			ctBucketName = fmt.Sprintf("cloudtrail-%s-%s-an", ctHostAcc.id, ssoRegion)
			ctAliasArn = fmt.Sprintf("arn:aws:kms:%s:%s:alias/cloudtrail-%s", ssoRegion, ctHostAcc.id, orgName)
			ctOpsId = ctOpsAcc.id
		}

		// Build import blocks for pre-existing delegated administrators.
		// Import id format for aws_organizations_delegated_administrator
		// is "<account_id>/<service_principal>".
		var importBlocks strings.Builder
		for _, acc := range orgAccs {
			for _, svc := range acc.importedDelegSP {
				fmt.Fprintf(&importBlocks, "\nimport {\n  to = module.org.aws_organizations_delegated_administrator.delegated[\"%s/%s\"]\n  id = \"%s/%s\"\n}\n",
					acc.key, svc, acc.id, svc)
			}
		}

		// Build accounts map for tfvars.json
		accountsMap := map[string]interface{}{}
		for _, acc := range orgAccs {
			entry := map[string]interface{}{"email": acc.email}
			if acc.iamBill != "" {
				entry["iam_user_access_to_billing"] = acc.iamBill
			}
			if acc.roleName != "" {
				entry["role_name"] = acc.roleName
			}
			if len(acc.delegatedSP) > 0 {
				entry["delegated_services"] = acc.delegatedSP
			}
			if acc.parentOU != "" {
				entry["parent_ou"] = acc.parentOU
			}
			accountsMap[acc.key] = entry
		}

		os.MkdirAll(filepath.Join(ctx.WorkDir, orgDir), 0o755)

		orgTags := mergeMaps(stateTags, map[string]string{
			"org_name":                 orgName,
			"account_id":               orgAccID,
			"profile":                  stateProfile,
			"region":                   ssoRegion,
			"has_lock":                 hasLock(ctx, orgDir),
			"has_tfvars":               "true",
			"import_blocks":            importBlocks.String(),
			"cloudtrail_enabled":       ctEnabled,
			"cloudtrail_trail_name":    ctTrailName,
			"cloudtrail_bucket_name":   ctBucketName,
			"cloudtrail_kms_alias_arn": ctAliasArn,
		})
		ctx.StampFromCUE(awsTemplate, orgDir, orgTags,
			[]gen.StampFile{
				{Field: "org_main_tf", Filename: "main.tf"},
				{Field: "org_variables_tf", Filename: "variables.tf"},
				{Field: "mise_toml", Filename: "mise.toml"},
				{Field: "component_build_bazel", Filename: "BUILD.bazel"},
			})

		// terraform.auto.tfvars.json -- use ordered output matching BBS cheshire
		accountsJSON, _ := json.MarshalIndent(accountsMap, "\t", "\t")
		var tfvarsBuf strings.Builder
		tfvarsBuf.WriteString("{\n\t\"region\": ")
		tfvarsBuf.WriteString(quote(ssoRegion))
		tfvarsBuf.WriteString(",\n\t\"cloudtrail_enabled\": ")
		tfvarsBuf.WriteString(ctEnabled) // "true" or "false" -- bare boolean, not quoted
		tfvarsBuf.WriteString(",\n\t\"cloudtrail_trail_name\": ")
		tfvarsBuf.WriteString(quote(ctTrailName))
		tfvarsBuf.WriteString(",\n\t\"cloudtrail_bucket_name\": ")
		tfvarsBuf.WriteString(quote(ctBucketName))
		tfvarsBuf.WriteString(",\n\t\"cloudtrail_kms_alias_arn\": ")
		tfvarsBuf.WriteString(quote(ctAliasArn))
		tfvarsBuf.WriteString(",\n\t\"accounts\": ")
		tfvarsBuf.WriteString(string(accountsJSON))
		tfvarsBuf.WriteString("\n}\n")
		tfvarsPath := filepath.Join(ctx.WorkDir, orgDir, "terraform.auto.tfvars.json")
		gen.WriteIfChanged(tfvarsPath, []byte(tfvarsBuf.String()), 0o644)
		ctx.LogOK(fmt.Sprintf("generated %s/", orgDir))

		// Per-account directories (sequential within org)
		// Skip accounts with no id yet -- they exist only in org-level tfvars
		// until tofu apply creates them and the id is backfilled in catalog.
		for _, acc := range orgAccs {
			if acc.id == "" {
				continue
			}
			accDir := orgDir + "/" + acc.name
			os.MkdirAll(filepath.Join(ctx.WorkDir, accDir), 0o755)
			outboundFed := "false"
			if acc.outboundFed {
				outboundFed = "true"
			}
			accessAnalyzerAdmin := "false"
			if len(acc.delegatedSP) > 0 {
				accessAnalyzerAdmin = "true"
			}
			accTags := mergeMaps(stateTags, map[string]string{
				"full_name":                  acc.key,
				"org_name":                   orgName,
				"account_id":                 acc.id,
				"org_account_id":             orgAccID,
				"profile":                    stateProfile,
				"region":                     ssoRegion,
				"has_lock":                   hasLock(ctx, accDir),
				"outbound_federation":        outboundFed,
				"access_analyzer_admin":      accessAnalyzerAdmin,
				"per_region_provider_blocks": buildPerRegionProviderBlocks(stateProfile, acc.id, orgName, allowedRegions),
			})
			// Pick the per-account template variant. Bucket-host accounts
			// get extra `module` blocks alongside `module "account"`. The
			// CloudTrail bucket stack only renders once the host id and
			// the ops id are both known (ctEnabled == "true"); the pub
			// bucket has no cross-account dependency so it renders as
			// soon as pub_bucket_host is set.
			mainTfField := "account_main_tf"
			ctReady := acc.cloudtrailBucketHost && ctEnabled == "true"
			switch {
			case ctReady && acc.pubBucketHost:
				mainTfField = "account_main_tf_with_cloudtrail_and_pub"
				accTags["cloudtrail_mgmt_account_id"] = orgAccID
				accTags["cloudtrail_ops_account_id"] = ctOpsId
				accTags["cloudtrail_trail_name"] = ctTrailName
				if pubPriceClass != "" {
					accTags["pub_price_class"] = pubPriceClass
				}
			case ctReady:
				mainTfField = "account_main_tf_with_cloudtrail"
				accTags["cloudtrail_mgmt_account_id"] = orgAccID
				accTags["cloudtrail_ops_account_id"] = ctOpsId
				accTags["cloudtrail_trail_name"] = ctTrailName
			case acc.pubBucketHost:
				mainTfField = "account_main_tf_with_pub"
				if pubPriceClass != "" {
					accTags["pub_price_class"] = pubPriceClass
				}
			}
			ctx.StampFromCUE(awsTemplate, accDir, accTags,
				[]gen.StampFile{
					{Field: mainTfField, Filename: "main.tf"},
					{Field: "mise_toml", Filename: "mise.toml"},
					{Field: "component_build_bazel", Filename: "BUILD.bazel"},
				})
			ctx.LogOK(fmt.Sprintf("generated %s/", accDir))
		}
		return nil
	}); err != nil {
		return fmt.Errorf("gen orgs: %w", err)
	}

	// Generate catalog/gen-infra-bricks.cue
	// Note: IRSA infra is now generated by k3d.Run() directly into k3d brick dirs.
	if err := genInfraBricks(ctx, orgEntries, byOrg); err != nil {
		return err
	}

	// Sidecar: claim .terraform.lock.hcl and other hand-tracked files per
	// infra brick dir. These are written by `terraform init` (not by this
	// generator), but are scoped to their brick dir and previously needed
	// a spec/manual-files.cue entry each.
	return writeInfraInputs(ctx)
}

// writeInfraInputs walks infra/ for .terraform.lock.hcl files and emits
// the per-brick roster into go/lib/gen/infra/contract.cue's
// generated inputs block. The infra contract concatenates these into
// its claims list.
func writeInfraInputs(ctx *gen.Context) error {
	inputs := make(map[string][]string)
	infraBase := "tenant/" + ctx.DefaultTenant() + "/infra"
	infraRoot := filepath.Join(ctx.WorkDir, infraBase)
	err := filepath.WalkDir(infraRoot, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if d.Name() != ".terraform.lock.hcl" {
			return nil
		}
		rel, err := filepath.Rel(ctx.WorkDir, path)
		if err != nil {
			return err
		}
		brickDir := filepath.Dir(rel)
		inputs[brickDir] = append(inputs[brickDir], d.Name())
		return nil
	})
	if err != nil {
		return fmt.Errorf("walk infra/: %w", err)
	}
	for k := range inputs {
		sort.Strings(inputs[k])
	}
	return golib.WriteInputsBlock(ctx, "tenant/library/go/lib/gen/infra", "infra", "_infra_inputs", inputs)
}

func genInfraBricks(ctx *gen.Context, orgEntries []orgInfo, byOrg map[string][]accInfo) error {
	tenant := ctx.DefaultTenant()
	infraBase := "tenant/" + tenant + "/infra"
	var sb strings.Builder
	sb.WriteString("@experiment(aliasv2,explicitopen,shortcircuit,try)\n\n")
	sb.WriteString("// gen-infra-bricks.cue -- generated by defn gen from AWS catalog.\n")
	sb.WriteString("// DO NOT EDIT. Run: mise run gen\n")
	sb.WriteString("package catalog\n\n")
	sb.WriteString("import \"github.com/defn/other/kernel/schema\"\n\n")
	sb.WriteString("bricks: [string]: schema.#Brick\n\n")
	fmt.Fprintf(&sb, "// infra branch\nbricks: %q: {\n", infraBase)
	fmt.Fprintf(&sb, "\tpath: %q\n", infraBase)
	sb.WriteString("\tslug: \"infra\"\n")
	sb.WriteString("\tkind: \"branch\"\n")
	sb.WriteString("\treads: []\n")
	sb.WriteString("\twrites: []\n")
	sb.WriteString("\tdesc: \"infra instances\"\n")
	sb.WriteString("\tcomposes: [\n")
	fmt.Fprintf(&sb, "\t\t%q,\n", infraBase+"/.mise/tasks")
	fmt.Fprintf(&sb, "\t\t%q,\n", infraBase+"/global")
	fmt.Fprintf(&sb, "\t\t%q,\n", infraBase+"/org")
	for _, oe := range orgEntries {
		fmt.Fprintf(&sb, "\t\t%q,\n", infraBase+"/org/"+oe.name)
	}
	sb.WriteString("\t]\n}\n\n")

	// infra/org branch
	fmt.Fprintf(&sb, "bricks: %q: {\n", infraBase+"/org")
	fmt.Fprintf(&sb, "\tpath: %q\n", infraBase+"/org")
	sb.WriteString("\tslug: \"infra--org\"\n")
	sb.WriteString("\tkind: \"branch\"\n")
	sb.WriteString("\treads: []\n")
	sb.WriteString("\twrites: []\n")
	sb.WriteString("\tdesc: \"per-org infrastructure instances\"\n")
	sb.WriteString("\tcomposes: [\n")
	for _, oe := range orgEntries {
		fmt.Fprintf(&sb, "\t\t%q,\n", infraBase+"/org/"+oe.name)
	}
	sb.WriteString("\t]\n}\n\n")

	// infra/global component
	fmt.Fprintf(&sb, "bricks: %q: {\n", infraBase+"/global")
	fmt.Fprintf(&sb, "\tpath:       %q\n", infraBase+"/global")
	sb.WriteString("\tslug:       \"infra--global\"\n")
	sb.WriteString("\tkind:       \"component\"\n")
	sb.WriteString("\treads: []\n")
	sb.WriteString("\twrites: []\n")
	sb.WriteString("\tdesc:       \"cross-account infrastructure\"\n")
	sb.WriteString("\timplements: \"kernel/module/aws-account\"\n")
	sb.WriteString("}\n\n")

	// Per-org bricks
	for _, oe := range orgEntries {
		orgPath := infraBase + "/org/" + oe.name
		fmt.Fprintf(&sb, "bricks: \"%s\": {\n", orgPath)
		fmt.Fprintf(&sb, "\tpath:       \"%s\"\n", orgPath)
		fmt.Fprintf(&sb, "\tslug:       \"infra--org--%s\"\n", oe.name)
		sb.WriteString("\tkind:       \"component\"\n")
		sb.WriteString("\treads: []\n")
		sb.WriteString("\twrites: []\n")
		fmt.Fprintf(&sb, "\tdesc:       \"%s org infrastructure\"\n", oe.name)
		sb.WriteString("\timplements: \"kernel/module/aws-org\"\n")
		sb.WriteString("}\n\n")

		for _, acc := range byOrg[oe.name] {
			accPath := orgPath + "/" + acc.name
			// Skip accounts whose directory hasn't been provisioned
			// yet -- avoids dangling brick declarations that point at
			// non-existent paths (caught by validate.CheckBricks).
			if info, err := os.Stat(filepath.Join(ctx.WorkDir, accPath)); err != nil || !info.IsDir() {
				continue
			}
			fmt.Fprintf(&sb, "bricks: \"%s\": {\n", accPath)
			fmt.Fprintf(&sb, "\tpath:       \"%s\"\n", accPath)
			fmt.Fprintf(&sb, "\tslug:       \"infra--org--%s--%s\"\n", oe.name, acc.name)
			sb.WriteString("\tkind:       \"component\"\n")
			sb.WriteString("\treads: []\n")
			sb.WriteString("\twrites: []\n")
			fmt.Fprintf(&sb, "\tdesc:       \"%s account infrastructure\"\n", acc.key)
			sb.WriteString("\timplements: \"kernel/module/aws-account\"\n")
			sb.WriteString("}\n\n")
		}
	}

	// Per AIDR-00071, gen-infra-bricks.cue lives in the owning
	// tenant's catalog/ since every brick it registers is under
	// that tenant's tree.
	outPath := "tenant/" + tenant + "/catalog/gen-infra-bricks.cue"
	if _, err := ctx.WriteCUEFmtIfChanged(outPath, []byte(sb.String())); err != nil {
		return fmt.Errorf("write %s: %w", outPath, err)
	}
	ctx.LogOK("generated " + outPath)
	return nil
}

func quote(s string) string {
	return `"` + s + `"`
}

// hclStringList renders a list of strings as an HCL list literal,
// e.g. ["us-east-1", "us-east-2"]. Stable sort + tofu fmt makes the
// output deterministic in the generated main.tf.
func hclStringList(items []string) string {
	if len(items) == 0 {
		return "[]"
	}
	sorted := make([]string, len(items))
	copy(sorted, items)
	sort.Strings(sorted)
	var b strings.Builder
	b.WriteString("[")
	for i, s := range sorted {
		if i > 0 {
			b.WriteString(", ")
		}
		b.WriteString(`"`)
		b.WriteString(s)
		b.WriteString(`"`)
	}
	b.WriteString("]")
	return b.String()
}

func hasLock(ctx *gen.Context, dirPath string) string {
	lockFile := filepath.Join(ctx.WorkDir, dirPath, ".terraform.lock.hcl")
	if _, err := os.Stat(lockFile); err == nil {
		return "true"
	}
	return "false"
}

func mergeMaps(base, extra map[string]string) map[string]string {
	result := make(map[string]string, len(base)+len(extra))
	for k, v := range base {
		result[k] = v
	}
	for k, v := range extra {
		result[k] = v
	}
	return result
}

// regionAlias renders a region name like "us-east-1" as an HCL-safe
// provider alias name like "region_us_east_1". Used by every
// per-region resource pair in module/aws-account/regions.gen.tf and
// by the provider blocks stamped into per-account main.tf.
func regionAlias(region string) string {
	return "region_" + strings.ReplaceAll(region, "-", "_")
}

// buildPerRegionProviderMap returns the inner body of the
// `providers = { ... }` map passed from a per-account main.tf to
// module "account". One line per allowed region.
func buildPerRegionProviderMap(regions []string) string {
	sorted := make([]string, len(regions))
	copy(sorted, regions)
	sort.Strings(sorted)
	var b strings.Builder
	for i, r := range sorted {
		if i > 0 {
			b.WriteString("\n")
		}
		alias := regionAlias(r)
		fmt.Fprintf(&b, "    aws.%s = aws.%s", alias, alias)
	}
	return b.String()
}

// buildPerRegionProviderBlocks returns N `provider "aws" { alias = ... }`
// blocks, one per allowed region. All use the same state profile and
// the per-account assume-role chain (<org>-ops-terraform on the
// target account). Stamped into the per-account main.tf after the
// existing `aws.cloudtrail` alias.
func buildPerRegionProviderBlocks(profile, accountID, orgName string, regions []string) string {
	sorted := make([]string, len(regions))
	copy(sorted, regions)
	sort.Strings(sorted)
	var b strings.Builder
	for _, r := range sorted {
		alias := regionAlias(r)
		fmt.Fprintf(&b, "\nprovider \"aws\" {\n  alias   = \"%s\"\n  profile = \"%s\"\n  region  = \"%s\"\n  assume_role {\n    role_arn = \"arn:aws:iam::%s:role/%s-ops-terraform\"\n  }\n}\n",
			alias, profile, r, accountID, orgName)
	}
	return b.String()
}

// stampAccountRegionsTf writes module/aws-account/regions.gen.tf
// from the allowed-regions list. The file declares one
// configuration_alias per region plus one EBS encryption default
// and one default SG strip per region.
func stampAccountRegionsTf(ctx *gen.Context, regions []string) error {
	sorted := make([]string, len(regions))
	copy(sorted, regions)
	sort.Strings(sorted)

	var b strings.Builder
	b.WriteString("# auto-generated by defn gen from catalog/aws.cue aws_allowed_regions.\n")
	b.WriteString("# DO NOT EDIT -- edit catalog/aws.cue and run `mise run gen`.\n\n")
	b.WriteString("terraform {\n")
	b.WriteString("  required_providers {\n")
	b.WriteString("    aws = {\n")
	b.WriteString("      source  = \"hashicorp/aws\"\n")
	b.WriteString("      version = \"6.40.0\"\n")
	b.WriteString("      configuration_aliases = [\n")
	for _, r := range sorted {
		fmt.Fprintf(&b, "        aws.%s,\n", regionAlias(r))
	}
	b.WriteString("      ]\n")
	b.WriteString("    }\n")
	b.WriteString("  }\n")
	b.WriteString("}\n")

	for _, r := range sorted {
		alias := regionAlias(r)
		fmt.Fprintf(&b, "\nresource \"aws_ebs_encryption_by_default\" \"%s\" {\n  provider = aws.%s\n  enabled  = true\n}\n", alias, alias)
		// NOTE: aws_default_security_group resources were dropped --
		// they fail with "reading Default Security Group: empty
		// result" on accounts that have no default VPC in the target
		// region. See ~/TODO.md for the resilient-adoption follow-up.
	}

	outPath := filepath.Join(ctx.WorkDir, "kernel/module/aws-account/regions.gen.tf")
	if _, err := gen.WriteIfChanged(outPath, []byte(b.String()), 0o644); err != nil {
		return fmt.Errorf("write module/aws-account/regions.gen.tf: %w", err)
	}
	return nil
}
