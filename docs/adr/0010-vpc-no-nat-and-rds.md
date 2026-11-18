# ADR 0010: VPC without NAT, and RDS Postgres defaults

## Status
Accepted

## Context
TSL-8 adds the first real environment resources: a VPC and a Postgres database in `environments/dev`. dev auto-applies on merge (ADR 0009), so merging creates a database that bills by the hour.

The API will run on ECS Fargate (TSL-18, which will supersede ADR 0001's App Runner choice). Fargate tasks need outbound access to AWS services (ECR to pull images, Secrets Manager for the DB password, CloudWatch Logs). The textbook layout puts tasks in private subnets and reaches those services through one of:

- **NAT Gateway**: about $33/mo per AZ, plus data fees.
- **Interface VPC endpoints** for ECR (two), Secrets Manager and Logs: about $7/mo each per AZ, so about $58/mo for 2 AZs.

Either would cost several times more than the database itself (about $14/mo).

## Decision
**Network** (`modules/network`):
- One VPC, `10.0.0.0/16`, with a public and a private `/24` subnet in each of 2 AZs.
- Public subnets route to an internet gateway. The API's Fargate tasks will run there with public IPs. Their security group is the only barrier: it will allow inbound traffic only from the load balancer (TSL-18).
- Private subnets have no internet route at all. Only the database lives there.
- No NAT Gateway and no interface endpoints. CI's apply role isn't even allowed to create a NAT Gateway or Elastic IP.
- A free S3 gateway endpoint on both route tables, so image layer pulls (ECR stores them in S3) stay on the AWS network.
- The VPC's default security group is taken over with no rules (deny-all).
- An empty `api` security group is created here, so the database can trust it today. TSL-18 attaches it to the ECS service and adds its rules.

**Database** (`modules/database`):
- RDS Postgres 18 (major version pinned, minor versions auto-upgrade), gp3 storage, encrypted with the AWS-managed key.
- `manage_master_user_password = true`. RDS generates the admin password and keeps it in Secrets Manager. It never appears in code, plans or state, which matters in a public repo. RDS rotates it every 7 days, so the API reads it from Secrets Manager instead of caching it.
- Inbound on 5432 only from the security groups passed in (the `api` group). No egress rules.
- TLS required (`rds.force_ssl`). IAM database authentication is turned on for later use. Performance Insights is on (free 7-day tier).
- Logging keeps credentials and user data out: slow queries (over 1s) are logged without their bound values (`log_parameter_max_length = 0`), and there's no statement logging (`log_statement`), because even `ddl` writes `CREATE ROLE ... PASSWORD` in plain text. Each log export (`postgresql`, `upgrade`) gets a Terraform-managed log group with 7-day retention.
- Safe defaults in the module (deletion protection on, final snapshot, 7-day backups). dev overrides them to be disposable: db.t4g.micro, single-AZ, 20 GB, 1-day backups, no deletion protection, no final snapshot. That comes to about $14/mo, always on.

**Cost guard**: an AWS Budgets alert in `bootstrap/` for the whole account ($25/mo by default). It emails at 80% actual, 100% forecast and 100% actual. The email address is read from SSM Parameter Store, so it stays out of the public repo.

**Permissions**: `dev-apply` gets EC2 networking, RDS, RDS log group and RDS-managed-secret write permissions (`bootstrap/ci-policies.tf`). It's limited to us-east-1, with Deny guardrails that stop it from touching or creating anything tagged as another environment. Every CI role also gets a new guardrail: it can see log groups but can't read what's in them, the same rule as for state files and secrets (ADR 0008).

## Consequences
Saves about $33–58/mo per environment compared with the textbook private-subnet layout, while the database still gets full private isolation.

Accepted risk (**revisit before prod has real users**):
- API tasks have public IPs, so their security group is the only layer keeping the internet out. A misconfigured rule would expose them directly, with no private-subnet layer behind it (no defense in depth).
- Security audits (SOC 2, PCI) usually expect workloads in private subnets.
- **Trigger**: before prod serves real users, or holds data that someone other than the developer cares about, move prod's tasks to private subnets with interface endpoints (or a NAT Gateway). Tasks are stateless, so that's a redeploy into different subnets. The database doesn't change.

Other trade-offs, also to revisit with real users:
- No VPC flow logs (CloudWatch bills per GB, and nobody reviews them yet).
- Single-AZ database in dev. Multi-AZ is one variable (`multi_az`) and doubles the instance cost. Turn it on for prod.
- No enhanced monitoring. Performance Insights covers query-level debugging.
- The AWS-managed KMS keys are used everywhere instead of customer-managed keys.
- All environments share one account, so the managed-secret permission (`rds!*`) isn't limited per environment. The tag guardrails cover the EC2 and RDS resources themselves.
- The $25 budget will be exceeded once TSL-18 adds a load balancer (about $16/mo or more). Raise `monthly_budget_usd` then.
