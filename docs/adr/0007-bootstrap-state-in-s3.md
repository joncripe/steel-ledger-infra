# ADR 0007: Bootstrap state stored in the bucket it creates

## Status
Accepted

## Context
`bootstrap/` creates the S3 state bucket that every other config uses as its backend. It can't use that bucket before the bucket exists (chicken-and-egg), so its state started out local. A local state file is a single copy on one laptop: if it's lost, the bucket, OIDC provider, CI roles and ECR repository become unmanaged.

## Decision
After the bucket existed, `bootstrap/` state was migrated into it with `terraform init -migrate-state`, under its own key (`bootstrap/terraform.tfstate`), using the same `use_lockfile` locking as everything else (ADR 0004).

## Consequences
Bootstrap state is versioned, encrypted, and no longer tied to one machine. The bucket has `prevent_destroy`, so `terraform destroy` can't remove the bucket that holds its own state.

Trade-off: if the bucket itself is ever lost, bootstrap has to be recovered by hand:

1. Comment out the `backend "s3"` block in `bootstrap/versions.tf`.
2. Run `terraform init -migrate-state` to pull the state back to local (or start with an empty local state if the bucket is gone).
3. Recreate the bucket with `apply` (or `import` resources that still exist).
4. Restore the backend block and run `terraform init -migrate-state` again.

The backend block can't read variables, so its `bucket` value must match `var.state_bucket_name` by hand.
