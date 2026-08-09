# ADR 0004: S3 native locking over DynamoDB lock table

## Status
Accepted

## Context
Terraform state needs a lock so concurrent `apply`s can't corrupt it. The traditional pattern pairs an S3 backend with a DynamoDB table for locking. Terraform's S3 backend now supports native locking via `use_lockfile`, which writes a lock file alongside the state object in the same bucket instead of a separate table.

## Decision
S3 backend with `use_lockfile = true`, no DynamoDB table.

## Consequences
One fewer resource to provision, permission, and pay for, and one fewer thing the `bootstrap/` config has to create before every other config can use a remote backend. Trade-off: native S3 locking has no automatic lock-staleness detection the way DynamoDB TTL-style cleanup can provide, so a crashed `apply` can leave a stale lock that needs manual `terraform force-unlock`. Given this project's solo, low-concurrency usage, that trade-off is acceptable.
