# ADR 0005: GitHub OIDC over long-lived access keys for CI

## Status
Accepted

## Context
GitHub Actions workflows need AWS credentials to run Terraform and, later, deploy. The traditional approach is to create an IAM user and store its access key ID and secret as GitHub repo secrets. Those keys never expire unless rotated by hand, and if they leak they work from anywhere. GitHub Actions can instead mint a short-lived OIDC token for each job, which AWS can exchange for temporary role credentials through `sts:AssumeRoleWithWebIdentity`.

## Decision
CI authenticates to AWS with GitHub OIDC. No IAM access keys are stored in GitHub.

- One `aws_iam_openid_connect_provider` for `token.actions.githubusercontent.com`, managed in `bootstrap/`. AWS allows one provider per issuer URL per account, and every environment's CI role trusts it.
- One IAM role per environment (`steel-ledger-{dev,stage,prod}-gha`; stage and prod trust only PRs, `main`, and their own GitHub Environment). Each role's trust policy requires `aud = sts.amazonaws.com` and restricts `sub` to this repo.
- The dev role starts with `ReadOnlyAccess` to prove the wiring end to end, using `sub = repo:joncripe@17099383/steel-ledger-infra@1319805938:*`. GitHub's `sub` claim includes the owner's and repo's immutable numeric IDs, so a renamed repo, or a new repo re-created under the same name, can't inherit the trust.

## Consequences
No secrets to rotate or leak. Credentials last at most an hour and only work for jobs running in this repo. Adding an environment means adding a role, not a new key.

Trade-offs:
- The `:*` subject trusts any branch, tag, or PR in the repo. That's acceptable while the role is read-only, but it must be narrowed (for example to `ref:refs/heads/main` or a GitHub environment) before any role gets write access.
- `ReadOnlyAccess` includes `s3:GetObject`, so any workflow in the repo can read every Terraform state file. That's acceptable for dev. Stage and prod roles therefore get no policy at all until TSL-19 gives them scoped ones.
- The OIDC provider is account-wide and lives in `bootstrap/`, so deleting or breaking it cuts off CI for every environment at once.
