# Monthly cost alarm for the whole AWS account (every environment, plus
# the EC2 Mac). TSL-8 adds the first resource that bills by the hour.
#
# The alert email lives in SSM Parameter Store, not in code: this repo is
# public. Create it once, by hand, before planning bootstrap:
#
#   aws ssm put-parameter --name /steel-ledger/budget-alert-email \
#     --type String --value "<your email>"
#
# (String, not SecureString: CI's ReadOnlyAccess can't decrypt KMS. The
# value is still marked sensitive in plans.) AWS emails that address once
# to confirm the subscription.

data "aws_ssm_parameter" "budget_alert_email" {
  name = var.budget_alert_email_parameter
}

locals {
  budget_emails = [data.aws_ssm_parameter.budget_alert_email.value]
}

resource "aws_budgets_budget" "monthly" {
  name         = "steel-ledger-monthly"
  budget_type  = "COST"
  limit_amount = format("%.1f", var.monthly_budget_usd) # AWS stores "25.0"; match it to avoid a diff
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Early warning: real spend passed 80%.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = local.budget_emails
  }

  # AWS predicts the month will end over budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = local.budget_emails
  }

  # Over budget.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = local.budget_emails
  }

  tags = {
    Project   = "steel-ledger"
    ManagedBy = "terraform"
  }
}
