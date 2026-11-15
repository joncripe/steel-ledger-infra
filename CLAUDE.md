# CLAUDE.md

## What this repo is
Terraform for all AWS infra behind **The Steel Ledger**: RDS, App Runner, S3, Secrets Manager, and the EC2 Mac dev-environment module.

## Where the "why" lives
- Full project scope: [Confluence](https://joncripe.atlassian.net/wiki/spaces/TSL/pages/66041)
- Infra decisions: [`/docs/adr`](./docs/adr)
- Jira: project `TSL`, Epic 1 = `TSL-4`

## Stack
Terraform, AWS. State: S3 backend with native locking (`use_lockfile`), no DynamoDB table. One reusable module, per-environment `.tfvars` (dev/stage/prod).

## Used by
`steel-ledger-api` and `steel-ledger-ios` depend on resources provisioned here. Their CLAUDE.md files link back to this repo rather than duplicating infra details.

## Conventions
- `terraform plan` before every `apply`, no exceptions, even solo
- New infra decision? Add an ADR to `/docs/adr`
- New root folder? Add it to `.github/terraform-roots.json`; its state key must sit under `<env>/` (ADR 0008)
- New resource type in an env? Add its write permissions to `bootstrap/ci-policies.tf` first (hand-applied)
- Public repo: CI never prints full plans, state or tfvars, only summaries

## CI (ADR 0008, 0009)
- PR: fmt, validate, tflint, checkov (inline `#checkov:skip` with a reason), plus a summary-only plan comment per root
- Merge to main: auto-applies `dev`. `stage`/`prod`: Actions → Terraform apply → Run workflow
- Roles: `steel-ledger-<env>-plan` (PRs, main) and `-apply` (only inside that GitHub Environment). Bootstrap has plan only

## Current status
`bootstrap/` is live: S3 state bucket (with version cleanup), GitHub OIDC provider, 7 CI roles (`bootstrap-plan`, `{dev,stage,prod}-{plan,apply}`), and ECR repo `steel-ledger-api`. `environments/{dev,stage,prod}` exist but are empty (backend + provider only). The EC2 Mac lives in `environments/dev-mac`: built and verified, then torn down, and off in CI until TSL-44. `Infra health` runs a nightly OIDC check. RDS, App Runner, Secrets Manager not started.
