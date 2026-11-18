# What each CI role (github-oidc.tf) is allowed to do. See ADR 0008.
#
#   every role - read AWS config (ReadOnlyAccess), but only its own state
#                file, and no secret values or log contents (guardrails below).
#   apply only - also write its own state file and lock.
#   infra apply - also build that env's VPC + database (TSL-8). Only envs
#                 listed in local.infra_envs get this.
#
# Each ticket that adds resources to an environment adds just the write
# permissions it needs here, reviewed and applied by hand.

data "aws_caller_identity" "current" {}

locals {
  state_bucket_arn = aws_s3_bucket.tf_state.arn
  account_id       = data.aws_caller_identity.current.account_id

  apply_roles = { for k, r in local.ci_roles : k => r if r.access == "apply" }

  # Environments whose apply role may build real resources. stage and prod
  # join when their folders get code (they're still empty).
  infra_envs        = ["dev"]
  infra_apply_roles = { for k, r in local.apply_roles : k => r if contains(local.infra_envs, r.env) }

  # modules/network: VPC, subnets, internet gateway, route tables, the S3
  # gateway endpoint and security groups.
  #
  # Deliberately missing: ec2:CreateNatGateway and ec2:AllocateAddress.
  # The design has no NAT (ADR 0010), so CI can't add one by accident.
  network_write_actions = [
    "ec2:CreateVpc",
    "ec2:DeleteVpc",
    "ec2:ModifyVpcAttribute",
    "ec2:CreateSubnet",
    "ec2:DeleteSubnet",
    "ec2:ModifySubnetAttribute",
    "ec2:CreateInternetGateway",
    "ec2:DeleteInternetGateway",
    "ec2:AttachInternetGateway",
    "ec2:DetachInternetGateway",
    "ec2:CreateRouteTable",
    "ec2:DeleteRouteTable",
    "ec2:CreateRoute",
    "ec2:DeleteRoute",
    "ec2:ReplaceRoute",
    "ec2:AssociateRouteTable",
    "ec2:DisassociateRouteTable",
    "ec2:ReplaceRouteTableAssociation",
    "ec2:CreateVpcEndpoint",
    "ec2:ModifyVpcEndpoint",
    "ec2:DeleteVpcEndpoints",
    "ec2:CreateSecurityGroup",
    "ec2:DeleteSecurityGroup",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:ModifySecurityGroupRules",
    "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
    "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
    "ec2:CreateTags",
    "ec2:DeleteTags",
  ]

  # modules/database: the instance, its subnet group and parameter group.
  database_write_actions = [
    "rds:CreateDBInstance",
    "rds:ModifyDBInstance",
    "rds:DeleteDBInstance",
    "rds:RebootDBInstance",
    # No rds:CreateDBSnapshot: dev skips the final snapshot on delete. Add
    # it when stage/prod join infra_envs (their DBs keep a final snapshot).
    "rds:CreateDBSubnetGroup",
    "rds:ModifyDBSubnetGroup",
    "rds:DeleteDBSubnetGroup",
    "rds:CreateDBParameterGroup",
    "rds:ModifyDBParameterGroup",
    "rds:ResetDBParameterGroup",
    "rds:DeleteDBParameterGroup",
    "rds:AddTagsToResource",
    "rds:RemoveTagsFromResource",
  ]
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

  # Same for logs: seeing that a log group exists (and its retention) is
  # fine; reading what's in it is not. App and database logs can hold user
  # data or credentials, and plan roles run on PRs in a public repo.
  statement {
    sid    = "NoLogContents"
    effect = "Deny"
    actions = [
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:GetQueryResults",
      "logs:StartLiveTail",
      "logs:GetLogRecord",
      "logs:Unmask",
    ]
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

# Infra apply roles: build their own environment's VPC and database.
#
# EC2 and RDS permissions mostly can't be pinned to one resource ARN ahead
# of time (the IDs don't exist until create), so the allows use "*" limited
# to our region, and the Deny statements at the bottom keep each role off
# anything tagged as another environment. Every env's provider sets an
# Environment tag on everything it creates (default_tags).
data "aws_iam_policy_document" "ci_infra_write" {
  #checkov:skip=CKV_AWS_356:EC2/RDS resource IDs don't exist until create, so these allows use "*". They're limited to one region, and the Deny statements below block other environments' resources.
  #checkov:skip=CKV_AWS_111:Same as above. Write access is constrained by region and the environment-tag Deny statements, not by ARN.
  for_each = local.infra_apply_roles

  statement {
    sid       = "Network"
    actions   = local.network_write_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid       = "Database"
    actions   = local.database_write_actions
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # Postgres logs go to a log group Terraform creates first, so it gets a
  # short retention instead of RDS's default of "keep forever".
  # RDS names it /aws/rds/instance/<db identifier>/postgresql, and the
  # database module names the instance steel-ledger-<env>.
  statement {
    sid = "DatabaseLogGroups"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/aws/rds/instance/steel-ledger-${each.value.env}/*"]
  }

  # manage_master_user_password: RDS creates the DB password as a secret
  # named rds!db-<id>, using the caller's permissions. CI never reads the
  # value (the NoSecretValues guardrail still applies).
  statement {
    sid = "RdsManagedPassword"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:RotateSecret",
      "secretsmanager:DeleteSecret",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:rds!*"]
  }

  # The first RDS instance in an account creates the AWSServiceRoleForRDS
  # role (a helper role AWS uses to manage the DB's network interfaces).
  # This account doesn't have it yet.
  statement {
    sid       = "RdsServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["rds.amazonaws.com"]
    }
  }

  # Guardrails: never touch, or create, something tagged as another env.
  # Untagged resources (and actions that don't support tags) aren't
  # matched, so these only ever block, never break, a normal apply.
  statement {
    sid       = "NotOtherEnvironments"
    effect    = "Deny"
    actions   = concat(local.network_write_actions, local.database_write_actions)
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:ResourceTag/Environment"
      values   = ["false"] # the tag exists...
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [each.value.env] # ...and it's not this env
    }
  }

  statement {
    sid       = "NoCreatingOtherEnvironments"
    effect    = "Deny"
    actions   = concat(local.network_write_actions, local.database_write_actions)
    resources = ["*"]

    condition {
      test     = "Null"
      variable = "aws:RequestTag/Environment"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestTag/Environment"
      values   = [each.value.env]
    }
  }
}

resource "aws_iam_role_policy" "ci_infra_write" {
  for_each = local.infra_apply_roles

  name   = "infra-write"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.ci_infra_write[each.key].json
}
