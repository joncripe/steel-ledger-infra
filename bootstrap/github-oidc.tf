# GitHub Actions -> AWS via OIDC, so workflows get short-lived credentials
# instead of long-lived access keys stored as repo secrets.
#
# Lives in bootstrap/ because the OIDC provider is account-wide (one per
# issuer URL per account) and every CI role trusts it.
#
# Roles are split by what they can do (ADR 0008):
#   <env>-plan  - look only. Used by PR plans and nightly drift checks.
#   <env>-apply - can change things. Only a job running in that env's
#                 GitHub Environment can assume it (stage/prod need approval).
# Their permissions live in ci-policies.tf.

locals {
  github_repo = "joncripe/steel-ledger-infra"

  # GitHub's OIDC `sub` claim now embeds immutable numeric IDs:
  #   repo:<owner>@<owner_id>/<repo>@<repo_id>:<context>
  # The IDs never change, so a renamed or re-created repo with the same
  # name can't inherit this trust. Found via CloudTrail on the first run.
  github_sub_repo = "joncripe@17099383/steel-ledger-infra@1319805938"

  environments = ["dev", "stage", "prod"]

  # Contexts that may assume a plan role: any PR, plus main (Infra health's
  # nightly runs come from main). A job that sets `environment:` gets an
  # environment:<name> sub instead, so it can't use these.
  plan_subs = ["pull_request", "ref:refs/heads/main"]

  # Every CI role. Key = role suffix; state_prefix = the state keys it may
  # touch (<prefix>/...). bootstrap only gets a plan role: the pipeline
  # must never be able to edit its own permissions.
  ci_roles = merge(
    {
      "bootstrap-plan" = {
        env          = "bootstrap"
        access       = "plan"
        state_prefix = "bootstrap"
        subs         = local.plan_subs
      }
    },
    { for env in local.environments : "${env}-plan" => {
      env          = env
      access       = "plan"
      state_prefix = env
      subs         = local.plan_subs
    } },
    { for env in local.environments : "${env}-apply" => {
      env          = env
      access       = "apply"
      state_prefix = env
      subs         = ["environment:${env}"]
    } },
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # No thumbprint_list: AWS validates GitHub's OIDC certs against its own
  # trusted CA library, and the provider (>= 5.81) treats it as optional.

  tags = {
    Project   = "steel-ledger"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "ci_trust" {
  for_each = local.ci_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringEquals, not StringLike: every allowed context is spelled out,
    # so no wildcard can match more than intended.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for ctx in each.value.subs : "repo:${local.github_sub_repo}:${ctx}"]
    }
  }
}

resource "aws_iam_role" "ci" {
  for_each = local.ci_roles

  name               = "steel-ledger-${each.key}"
  description        = "GitHub Actions (${local.github_repo}) via OIDC: ${each.value.access} for ${each.value.env}."
  assume_role_policy = data.aws_iam_policy_document.ci_trust[each.key].json

  tags = {
    Project     = "steel-ledger"
    Environment = each.value.env
    Access      = each.value.access
    ManagedBy   = "terraform"
  }
}
