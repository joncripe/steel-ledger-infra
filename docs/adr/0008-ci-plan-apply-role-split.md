# ADR 0008: Separate plan and apply roles for CI

## Status
Accepted. Revises the role layout in ADR 0005.

## Context
ADR 0005 gave each environment one CI role. The dev role trusted anything in the repo (`sub = ...:*`) with account-wide `ReadOnlyAccess`, and stage and prod had no permissions. TSL-19 adds plan on every PR and apply on merge. That needs two different levels of access: a PR runs code that hasn't been reviewed yet, so it must never be able to change anything, while an apply job has to write state and, later, real resources.

All environments share one AWS account and one state bucket, so `ReadOnlyAccess` alone would let any PR read every environment's state file, and state can hold secrets.

## Decision
Each environment gets two roles, generated from one list in `bootstrap/github-oidc.tf`:

- `steel-ledger-<env>-plan` is look-only. It's trusted by `pull_request` and `ref:refs/heads/main` (the nightly Infra health checks run from main).
- `steel-ledger-<env>-apply` can write. It's trusted only by `environment:<env>`, so only a job running in that GitHub Environment can assume it. Stage and prod Environments require a reviewer; dev's doesn't.
- `bootstrap/` gets a plan role only. The pipeline must never be able to edit its own permissions, so bootstrap is always applied by hand.

Trust uses `StringEquals` on the full ID-based `sub`, with no wildcards.

Permissions (`bootstrap/ci-policies.tf`):

- Every role: `ReadOnlyAccess`, plus explicit Deny guardrails. It can only read state objects under its own `<env>/` prefix, and it can't read Secrets Manager values.
- Apply roles also get `s3:PutObject` on their own state prefix and `s3:DeleteObject` on their own `.tflock`.
- Apply roles get no resource write permissions yet. Each ticket that adds resources to an environment adds just the write permissions it needs, reviewed in a bootstrap PR and applied by hand.

## Consequences
Unreviewed PR code can see AWS settings, but can't change anything or read another environment's state. Write access sits behind a GitHub Environment, so stage and prod changes need an approval that IAM itself enforces. Adding an environment is one entry in the list.

Trade-offs:
- All environments share one account, so the `<env>-plan` roles can still see every environment's resource settings (not data). Separate accounts per environment would fix that, but they're too much overhead for now.
- Permissions grow ticket by ticket, so a new resource type needs a hand-applied bootstrap change before CI can deploy it. That's slower than broad `PowerUserAccess`, but every grant gets reviewed.
- When an environment manages secret values in Terraform, its roles will need the Secrets Manager deny loosened for that environment's own secrets.
- The new role names replace the old `*-gha` roles. Anything still using `steel-ledger-dev-gha` (main's nightly Infra health, until TSL-19 merges) fails once bootstrap is applied.
- State keys must live under `<env>/` (or `bootstrap/`), or the roles can't read them.
