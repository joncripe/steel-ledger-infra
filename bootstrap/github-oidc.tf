# GitHub Actions -> AWS via OIDC, so workflows get short-lived credentials
# instead of long-lived access keys stored as repo secrets.
#
# Lives in bootstrap/ because the OIDC provider is account-wide (one per
# issuer URL per account) and every environment's CI role trusts it.

locals {
  github_repo = "joncripe/steel-ledger-infra"

  # GitHub's OIDC `sub` claim now embeds immutable numeric IDs:
  #   repo:<owner>@<owner_id>/<repo>@<repo_id>:<context>
  # The IDs never change, so a renamed or re-created repo with the same
  # name can't inherit this trust. Found via CloudTrail on the first run.
  github_sub_repo = "joncripe@17099383/steel-ledger-infra@1319805938"

  # One CI role per environment. Each value lists the `sub` contexts that
  # may assume that role (any one match is enough).
  #   dev   - anything in this repo (branches, tags, PRs)
  #   stage - PRs (plan), main, or the `stage` GitHub Environment
  #   prod  - PRs (plan), main, or the `prod` GitHub Environment
  # Only dev has permissions (read-only). Stage and prod exist so their
  # trust is in place, but get no policy until TSL-19 scopes them; account-
  # wide ReadOnlyAccess would let any PR read every state file. Write access
  # and a plan/apply role split also come with TSL-19.
  gha_roles = {
    dev = ["*"]
    stage = [
      "pull_request",
      "ref:refs/heads/main",
      "environment:stage",
    ]
    prod = [
      "pull_request",
      "ref:refs/heads/main",
      "environment:prod",
    ]
  }
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

data "aws_iam_policy_document" "gha_trust" {
  for_each = local.gha_roles

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

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for ctx in each.value : "repo:${local.github_sub_repo}:${ctx}"]
    }
  }
}

resource "aws_iam_role" "gha" {
  for_each = local.gha_roles

  name               = "steel-ledger-${each.key}-gha"
  description        = "Assumed by GitHub Actions in ${local.github_repo} via OIDC (${each.key})."
  assume_role_policy = data.aws_iam_policy_document.gha_trust[each.key].json

  tags = {
    Project     = "steel-ledger"
    Environment = each.key
    ManagedBy   = "terraform"
  }
}

# Dev only, to prove the OIDC wiring. Replace with a scoped policy before
# CI needs to apply.
resource "aws_iam_role_policy_attachment" "gha_readonly" {
  for_each = toset(["dev"])

  role       = aws_iam_role.gha[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
