# What each CI role (github-oidc.tf) is allowed to do. See ADR 0008.
#
#   every role - read AWS config (ReadOnlyAccess), but only its own state
#                file and no secret values (guardrails below).
#   apply only - also write its own state file and lock.
#
# Apply roles can't change any real resources yet: stage/prod have no code.
# Each ticket that adds resources to an environment adds just the write
# permissions it needs here, reviewed and applied by hand.

locals {
  state_bucket_arn = aws_s3_bucket.tf_state.arn

  apply_roles = { for k, r in local.ci_roles : k => r if r.access == "apply" }
}

# Baseline: see every resource's settings, so `plan` can compare code to AWS.
resource "aws_iam_role_policy_attachment" "ci_read" {
  for_each = local.ci_roles

  role       = aws_iam_role.ci[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccess reads too much. These denies carve out data, not settings.
# An explicit Deny always beats an Allow, so nothing attached later can undo
# them by accident.
data "aws_iam_policy_document" "ci_guardrails" {
  for_each = local.ci_roles

  # State files hold every resource's attributes, sometimes including
  # passwords. A role may only read objects under its own state prefix.
  # (NotResource = "everything except". This also blocks reading objects in
  # any other bucket, which CI has no reason to do.)
  statement {
    sid           = "OnlyOwnStateObjects"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion"]
    not_resources = ["${local.state_bucket_arn}/${each.value.state_prefix}/*"]
  }

  # Seeing that a secret exists is fine; reading its value is not.
  # Revisit when an environment manages secret versions in Terraform.
  statement {
    sid       = "NoSecretValues"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:BatchGetSecretValue"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ci_guardrails" {
  for_each = local.ci_roles

  name   = "guardrails"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.ci_guardrails[each.key].json
}

# Apply roles: save state, and take/release the lock (use_lockfile writes a
# <key>.tflock object next to the state, then deletes it; ADR 0004).
# Reading state is already covered by ReadOnlyAccess + the guardrail.
data "aws_iam_policy_document" "ci_state_write" {
  for_each = local.apply_roles

  statement {
    sid       = "WriteOwnState"
    actions   = ["s3:PutObject"]
    resources = ["${local.state_bucket_arn}/${each.value.state_prefix}/*"]
  }

  statement {
    sid       = "ReleaseOwnLock"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${each.value.state_prefix}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "ci_state_write" {
  for_each = local.apply_roles

  name   = "state-write"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.ci_state_write[each.key].json
}
