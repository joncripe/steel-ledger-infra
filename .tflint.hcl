# TFLint config, shared by every Terraform folder in the repo.
#
# CI runs `tflint --recursive --config "$GITHUB_WORKSPACE/.tflint.hcl"`.
# In recursive mode a relative --config is looked up inside each folder, so
# the path must be absolute or the other folders get no rules.
#
# Locally (from the repo root):
#   tflint --init
#   tflint --recursive --config "$(pwd)/.tflint.hcl"

config {
  # Also check the modules that root folders call (modules/ec2-mac-dev).
  call_module_type = "local"
}

# Terraform language rules: unused variables, missing types, missing
# version pins, deprecated syntax.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules: catches mistakes `terraform validate` can't, like an instance
# type or region that doesn't exist.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
