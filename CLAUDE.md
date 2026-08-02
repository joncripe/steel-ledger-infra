# CLAUDE.md

## What this repo is
Terraform for all AWS infra behind **The Steel Ledger**: RDS, App Runner, S3, Secrets Manager, and the EC2 Mac dev-environment module.

## Where the "why" lives
- Full project scope: [Confluence](https://joncripe.atlassian.net/wiki/spaces/TSL/pages/66041)
- Infra decisions: [`/docs/adr`](./docs/adr)
- Jira: project `TSL`, Epic 1 = `TSL-4`

## Stack
Terraform, AWS. State: S3 backend + DynamoDB lock table. One reusable module, per-environment `.tfvars` (dev/stage/prod).

## Used by
`steel-ledger-api` and `steel-ledger-ios` depend on resources provisioned here. Their CLAUDE.md files link back to this repo rather than duplicating infra details.

## Conventions
- `terraform plan` before every `apply`, no exceptions, even solo
- New infra decision? Add an ADR to `/docs/adr`

## Current status
Pre-Terraform. Nothing provisioned yet. Update as modules are added.
