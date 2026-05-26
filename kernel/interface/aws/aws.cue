@experiment(aliasv2,explicitopen,shortcircuit,try)

// aws.cue -- AWS inventory re-exported from catalog.
package aws

import "github.com/defn/other/kernel/catalog"

// Re-export AWS orgs from catalog (source of truth).
aws_orgs: catalog.aws_orgs

// Re-export AWS accounts from catalog (source of truth).
aws_accounts: catalog.aws_accounts
