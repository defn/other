@experiment(aliasv2,explicitopen,shortcircuit,try)

// templates.cue -- AWS infra BUILD.bazel and Terraform generation.

import "github.com/defn/other/kernel/helpers"

_org_name:            *"" | string      @tag(org_name)
_full_name:           *"" | string      @tag(full_name)
_profile:             *"" | string      @tag(profile)
_region:              *"" | string      @tag(region)
_account_id:          *"" | string      @tag(account_id)
_org_account_id:      *"" | string      @tag(org_account_id)
_state_profile:       *"" | string      @tag(state_profile)
_state_account_id:    *"" | string      @tag(state_account_id)
_state_bucket:        *"" | string      @tag(state_bucket)
_state_region:        *"" | string      @tag(state_region)
_has_lock:            *"false" | string @tag(has_lock)
_has_tfvars:          *"false" | string @tag(has_tfvars)
_import_blocks:       *"" | string      @tag(import_blocks)
_outbound_federation: *"false" | string @tag(outbound_federation)
_provider_entries:    *"" | string      @tag(provider_entries)
_cluster_name:        *"" | string      @tag(cluster_name)
_cluster_dir:         *"" | string      @tag(cluster_dir)
_irsa_role_prefix:    *"" | string      @tag(irsa_role_prefix)
_module_depth:        *"" | string      @tag(module_depth)

// CloudTrail per-org metadata. Stamped into the org main.tf so the
// org stack can wire `module "org"` to the bucket and KMS alias the
// host stack creates. cloudtrail_enabled stays "false" until the
// host account exists and its id is known.
_cloudtrail_enabled:       *"false" | string @tag(cloudtrail_enabled)
_cloudtrail_trail_name:    *"" | string      @tag(cloudtrail_trail_name)
_cloudtrail_bucket_name:   *"" | string      @tag(cloudtrail_bucket_name)
_cloudtrail_kms_alias_arn: *"" | string      @tag(cloudtrail_kms_alias_arn)

// CloudTrail per-host-account metadata. Used by
// account_main_tf_with_cloudtrail to stamp the bucket module call.
_cloudtrail_mgmt_account_id: *"" | string @tag(cloudtrail_mgmt_account_id)
_cloudtrail_ops_account_id:  *"" | string @tag(cloudtrail_ops_account_id)

// CloudFront price class for the per-account pub bucket distribution.
// Sourced from the org's pub_price_class field; default is the cheapest
// price class (US/Canada/Europe).
_pub_price_class: *"PriceClass_100" | string @tag(pub_price_class)

// Per-region provider plumbing for module/aws-account hardening.
// _per_region_provider_blocks is a string blob of N `provider "aws" {
// alias = "region_<r>" ... }` blocks, one per allowed region. The
// generator builds it per-account because the assume-role role_arn
// changes per account. _per_region_provider_map is the inner body of
// the `providers = { ... }` map passed to module "account"; one
// `aws.region_<r> = aws.region_<r>` line per allowed region.
_per_region_provider_blocks: *"" | string @tag(per_region_provider_blocks)
_per_region_provider_map:    *"" | string @tag(per_region_provider_map)

// IAM Access Analyzer organization-admin flag. The generator sets
// this to "true" on accounts whose delegated_services list is
// non-empty -- those are the per-org ops accounts that own
// access-analyzer delegation. The string ends up as the literal
// `true` or `false` boolean value of access_analyzer_org_admin in
// the module "account" call.
_access_analyzer_admin: *"false" | string @tag(access_analyzer_admin)

// Region policy. Both lists come from catalog/aws.cue and are
// rendered as HCL list literals by the generator. allowed flows
// into the RegionAllowlist SCP via module/aws-org; forbidden flows
// into per-account aws_account_region disables via module/aws-account.
_allowed_regions_hcl:   *"[]" | string @tag(allowed_regions_hcl)
_forbidden_regions_hcl: *"[]" | string @tag(forbidden_regions_hcl)

// bare_build_bazel -- loads + self only (for infra/org/)
bare_build_bazel: helpers.FmtLoads + "\n\n" + helpers.BuildBazelFmt + "\n\n" + helpers.BuildBazelTag + "\n\n" + helpers.DispatchCueRules

// parent_build_bazel -- self + mise.toml with config,toml tags (for infra/)
parent_build_bazel: helpers.FmtLoads + "\n\n" + helpers.BuildBazelFmt + "\n\n" + helpers.BuildBazelTag + "\n\n" + (helpers.FmtTest & {src: "mise.toml", tool: "taplo"}).out + "\n\n" + (helpers.TaggedFile & {src: "mise.toml", tags: ["config", "toml"]}).out + "\n\n" + helpers.DispatchCueRules

// component_build_bazel -- self + main.tf + mise.toml (generated) + optional lock/tfvars
_lock_section: string
if _has_lock == "true" {
	_lock_section: "\n\n" + (helpers.FmtTest & {src: ".terraform.lock.hcl", tool: "binary"}).out + "\n\n" + (helpers.TaggedFile & {src: ".terraform.lock.hcl", tags: ["lock"]}).out
}
if _has_lock != "true" {
	_lock_section: ""
}
_tfvars_section: string
if _has_tfvars == "true" {
	_tfvars_section: "\n\n" + (helpers.FmtTest & {src: "variables.tf", tool: "tofu"}).out + "\n\n" + (helpers.TaggedFile & {src: "variables.tf", tags: ["config", "generated"]}).out + "\n\n" + (helpers.FmtTest & {src: "terraform.auto.tfvars.json", tool: "biome"}).out + "\n\n" + (helpers.TaggedFile & {src: "terraform.auto.tfvars.json", tags: ["config", "generated", "json"]}).out
}
if _has_tfvars != "true" {
	_tfvars_section: ""
}

component_build_bazel: helpers.FmtLoads + "\n\n" + helpers.BuildBazelFmt + "\n\n" + helpers.BuildBazelTag + "\n\n" + (helpers.FmtTest & {src: "main.tf", tool: "tofu"}).out + "\n\n" + (helpers.TaggedFile & {src: "main.tf", tags: ["config", "generated"]}).out + "\n\n" + (helpers.FmtTest & {src: "mise.toml", tool: "taplo"}).out + "\n\n" + (helpers.TaggedFile & {src: "mise.toml", tags: ["config", "generated", "toml"]}).out + _lock_section + _tfvars_section + "\n\n" + helpers.DispatchCueRules

// bootstrap_override_tf -- temporary provider override for new account bootstrap.
// Uses the generated <org>-via-defn chained profile (master tofu
// profile from catalog.auth.tofu -> <org>-ops-terraform role) as the
// source session, then assumes the default OrganizationAccountAccessRole
// in the target account. This works deterministically without any
// per-org SSO login -- the chain is declared in generated ~/.aws/config.
bootstrap_override_tf: #"""
	# Temporary bootstrap override -- deleted after apply.
	# Uses OrganizationAccountAccessRole for first-time account setup.
	# Both the default provider and the aws.cloudtrail alias are
	# overridden so Pass-1 bootstrap of a fresh -log account can also
	# create the CloudTrail bucket on first apply.
	provider "aws" {
	  profile = "\#(_org_name)-via-defn"
	  region  = "\#(_state_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/OrganizationAccountAccessRole"
	  }
	}

	provider "aws" {
	  alias   = "cloudtrail"
	  profile = "\#(_org_name)-via-defn"
	  region  = "\#(_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/OrganizationAccountAccessRole"
	  }
	}
	"""#

// mise_toml -- env vars for profile + region
mise_toml: #"""
	[env]
	AWS_PROFILE = "\#(_profile)"
	AWS_REGION = "\#(_region)"
	"""#

// org_main_tf -- uses variables for profile/region/accounts
org_main_tf: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    profile        = "\#(_state_profile)"
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    key            = "stacks/org-\#(_org_name)/terraform.tfstate"
	    region         = "\#(_state_region)"
	    encrypt        = true
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = var.region
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}

	module "org" {
	  source = "../../../../../kernel/module/aws-org"

	  accounts = var.accounts

	  cloudtrail_enabled       = var.cloudtrail_enabled
	  cloudtrail_trail_name    = var.cloudtrail_trail_name
	  cloudtrail_bucket_name   = var.cloudtrail_bucket_name
	  cloudtrail_kms_alias_arn = var.cloudtrail_kms_alias_arn

	  allowed_regions = \#(_allowed_regions_hcl)
	}
	\#(_import_blocks)
	"""#

// org_variables_tf -- variable declarations for org level
org_variables_tf: """
	variable "region" {
	  type = string
	}

	variable "accounts" {
	  type = map(object({
	    email                      = string
	    iam_user_access_to_billing = optional(string)
	    role_name                  = optional(string)
	    delegated_services         = optional(list(string), [])
	    parent_ou                  = optional(string)
	  }))
	}

	variable "cloudtrail_enabled" {
	  type    = bool
	  default = false
	}

	variable "cloudtrail_trail_name" {
	  type    = string
	  default = ""
	}

	variable "cloudtrail_bucket_name" {
	  type    = string
	  default = ""
	}

	variable "cloudtrail_kms_alias_arn" {
	  type    = string
	  default = ""
	}
	"""

// account_main_tf -- literal providers and moved blocks. Every per-
// account stack declares two AWS providers: the default one pinned to
// the state region (matches the terraform backend, lets the state
// bucket and module/aws-account land where they always have), and an
// `aws.cloudtrail` alias pinned to the org's SSO region. Bucket-host
// accounts use the alias for the cloudtrail bucket; non-host accounts
// just have the alias declared so every per-account main.tf has the
// same shape.
account_main_tf: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/acc-\#(_full_name)/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = "\#(_state_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}

	provider "aws" {
	  alias   = "cloudtrail"
	  profile = "\#(_state_profile)"
	  region  = "\#(_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}
	\#(_per_region_provider_blocks)
	module "account" {
	  source                    = "../../../../../../kernel/module/aws-account"
	  state_account_id          = "\#(_state_account_id)"
	  namespace                 = "\#(_org_name)"
	  org_account_id            = "\#(_org_account_id)"
	  outbound_federation       = \#(_outbound_federation)
	  access_analyzer_org_admin = \#(_access_analyzer_admin)
	  disabled_regions          = \#(_forbidden_regions_hcl)

	  providers = {
	\#(_per_region_provider_map)
	  }
	}
	"""#

// account_main_tf_with_cloudtrail -- like account_main_tf but also
// stamps the module/aws-cloudtrail-bucket call. Selected for accounts
// marked cloudtrail_bucket_host: true in catalog/aws.cue.
//
// The bucket-host region (the org's SSO region) may differ from the
// state region used by module/aws-account. Declare a second provider
// alias pinned to the bucket region and pass it to the cloudtrail
// bucket module so the S3 + KMS resources land in the right region.
account_main_tf_with_cloudtrail: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/acc-\#(_full_name)/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = "\#(_state_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}

	provider "aws" {
	  alias   = "cloudtrail"
	  profile = "\#(_state_profile)"
	  region  = "\#(_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}
	\#(_per_region_provider_blocks)
	module "account" {
	  source                    = "../../../../../../kernel/module/aws-account"
	  state_account_id          = "\#(_state_account_id)"
	  namespace                 = "\#(_org_name)"
	  org_account_id            = "\#(_org_account_id)"
	  outbound_federation       = \#(_outbound_federation)
	  access_analyzer_org_admin = \#(_access_analyzer_admin)
	  disabled_regions          = \#(_forbidden_regions_hcl)

	  providers = {
	\#(_per_region_provider_map)
	  }
	}

	module "cloudtrail_bucket" {
	  source          = "../../../../../../kernel/module/aws-cloudtrail-bucket"
	  namespace       = "\#(_org_name)"
	  mgmt_account_id = "\#(_cloudtrail_mgmt_account_id)"
	  ops_account_id  = "\#(_cloudtrail_ops_account_id)"
	  trail_name      = "\#(_cloudtrail_trail_name)"
	  region          = "\#(_region)"
	  alias_name      = "cloudtrail-\#(_org_name)"

	  providers = {
	    aws = aws.cloudtrail
	  }
	}
	"""#

// account_main_tf_with_pub -- like account_main_tf but also stamps the
// module/aws-pub-bucket call. Selected for accounts marked
// pub_bucket_host: true in catalog/aws.cue. The pub bucket lives in the
// org's SSO region, so it reuses the aws.cloudtrail provider alias which
// is already pinned to that region.
account_main_tf_with_pub: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/acc-\#(_full_name)/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = "\#(_state_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}

	provider "aws" {
	  alias   = "cloudtrail"
	  profile = "\#(_state_profile)"
	  region  = "\#(_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}
	\#(_per_region_provider_blocks)
	module "account" {
	  source                    = "../../../../../../kernel/module/aws-account"
	  state_account_id          = "\#(_state_account_id)"
	  namespace                 = "\#(_org_name)"
	  org_account_id            = "\#(_org_account_id)"
	  outbound_federation       = \#(_outbound_federation)
	  access_analyzer_org_admin = \#(_access_analyzer_admin)
	  disabled_regions          = \#(_forbidden_regions_hcl)

	  providers = {
	\#(_per_region_provider_map)
	  }
	}

	module "pub_bucket" {
	  source      = "../../../../../../kernel/module/aws-pub-bucket"
	  namespace   = "\#(_org_name)"
	  region      = "\#(_region)"
	  price_class = "\#(_pub_price_class)"

	  providers = {
	    aws = aws.cloudtrail
	  }
	}
	"""#

// account_main_tf_with_cloudtrail_and_pub -- selected for accounts that
// host both the CloudTrail bucket and a pub bucket. No account currently
// has both flags set, but the schema permits it; this template ensures
// gen does not silently drop one of the modules if such an account is
// later added.
account_main_tf_with_cloudtrail_and_pub: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/acc-\#(_full_name)/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = "\#(_state_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}

	provider "aws" {
	  alias   = "cloudtrail"
	  profile = "\#(_state_profile)"
	  region  = "\#(_region)"
	  assume_role {
	    role_arn = "arn:aws:iam::\#(_account_id):role/\#(_org_name)-ops-terraform"
	  }
	}
	\#(_per_region_provider_blocks)
	module "account" {
	  source                    = "../../../../../../kernel/module/aws-account"
	  state_account_id          = "\#(_state_account_id)"
	  namespace                 = "\#(_org_name)"
	  org_account_id            = "\#(_org_account_id)"
	  outbound_federation       = \#(_outbound_federation)
	  access_analyzer_org_admin = \#(_access_analyzer_admin)
	  disabled_regions          = \#(_forbidden_regions_hcl)

	  providers = {
	\#(_per_region_provider_map)
	  }
	}

	module "cloudtrail_bucket" {
	  source          = "../../../../../../kernel/module/aws-cloudtrail-bucket"
	  namespace       = "\#(_org_name)"
	  mgmt_account_id = "\#(_cloudtrail_mgmt_account_id)"
	  ops_account_id  = "\#(_cloudtrail_ops_account_id)"
	  trail_name      = "\#(_cloudtrail_trail_name)"
	  region          = "\#(_region)"
	  alias_name      = "cloudtrail-\#(_org_name)"

	  providers = {
	    aws = aws.cloudtrail
	  }
	}

	module "pub_bucket" {
	  source      = "../../../../../../kernel/module/aws-pub-bucket"
	  namespace   = "\#(_org_name)"
	  region      = "\#(_region)"
	  price_class = "\#(_pub_price_class)"

	  providers = {
	    aws = aws.cloudtrail
	  }
	}
	"""#

// global_main_tf -- terraform block + pre-rendered provider/module entries
global_main_tf: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/global/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }

	}
	\#(_provider_entries)
	"""#

// irsa_main_tf -- per-k3d-cluster IRSA infrastructure
irsa_main_tf: #"""
	# auto-generated by defn gen
	terraform {
	  required_providers {
	    aws = {
	      version = "6.40.0"
	      source  = "aws"
	    }
	    time = {
	      version = "0.13.1"
	      source  = "time"
	    }
	    tls = {
	      version = "4.1.0"
	      source  = "tls"
	    }
	    local = {
	      version = "2.5.3"
	      source  = "local"
	    }
	    random = {
	      version = "3.7.2"
	      source  = "random"
	    }
	  }
	  backend "s3" {
	    bucket         = "\#(_state_bucket)"
	    use_lockfile   = true
	    use_path_style = true
	    encrypt        = true
	    key            = "stacks/irsa-\#(_cluster_name)/terraform.tfstate"
	    profile        = "\#(_state_profile)"
	    region         = "\#(_state_region)"
	  }
	}

	provider "aws" {
	  profile = "\#(_state_profile)"
	  region  = "\#(_state_region)"
	}

	module "irsa" {
	  source           = "\#(_module_depth)/kernel/module/aws-irsa"
	  cluster_name     = "\#(_cluster_name)"
	  region           = "\#(_state_region)"
	  irsa_role_prefix = "\#(_irsa_role_prefix)"
	}
	"""#

// irsa_gitignore -- ignore tofu runtime files
irsa_gitignore: """
	out/
	.terraform/
	"""

// irsa_build_bazel -- BUILD.bazel for IRSA infra directories
irsa_build_bazel: helpers.FmtLoads + "\n\n" + helpers.BuildBazelFmt + "\n\n" + helpers.BuildBazelTag + "\n\n" + (helpers.FmtTest & {src: "main.tf", tool: "tofu"}).out + "\n\n" + (helpers.TaggedFile & {src: "main.tf", tags: ["config", "generated"]}).out + "\n\n" + (helpers.FmtTest & {src: "mise.toml", tool: "taplo"}).out + "\n\n" + (helpers.TaggedFile & {src: "mise.toml", tags: ["config", "generated", "toml"]}).out + "\n\n" + (helpers.TaggedFile & {src: ".gitignore", tags: ["config", "git"]}).out + _lock_section + "\n\n" + helpers.DispatchCueRules
