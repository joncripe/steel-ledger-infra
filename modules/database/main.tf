# Postgres for one environment (ADR 0010).
#
# Lives in the private subnets: no public IP, no internet route. The only
# way in is the Postgres port, from the security groups passed in (the API
# service's group).
#
# The admin password is created and kept by RDS in Secrets Manager
# (manage_master_user_password). It never appears in code, plans or state.
# RDS rotates it every 7 days, so the API must read it from Secrets Manager
# rather than caching it forever (TSL-18).

locals {
  port = 5432

  # Logs RDS sends to CloudWatch. Each one gets a log group below, created
  # before the instance, so none falls back to RDS's keep-forever default.
  log_exports = ["postgresql", "upgrade"]
}

# --- Network access ----------------------------------------------------------

# Which subnets RDS may place the instance in. Two AZs are required even for
# single-AZ, so Multi-AZ can be turned on later without a rebuild.
resource "aws_db_subnet_group" "this" {
  name        = var.name
  description = "Private subnets for ${var.name} Postgres"
  subnet_ids  = var.subnet_ids

  tags = { Name = var.name }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "Postgres for ${var.name}: inbound 5432 from the API only"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db" }
}

# One rule per allowed group. The source is a security group, not an IP
# range, so it keeps working as tasks come and go.
# No egress rules: the database never starts connections of its own.
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = var.allowed_security_groups

  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from ${each.key}"
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port

  tags = { Name = "${var.name}-db-from-${each.key}" }
}

# --- Postgres settings -------------------------------------------------------

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name}-"
  family      = "postgres${var.engine_version}"
  description = "Postgres ${var.engine_version} settings for ${var.name}"

  # Refuse unencrypted connections (already the default since Postgres 15;
  # set explicitly so it can't drift).
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # No log_statement (statement logging). Even "ddl" would write
  # CREATE ROLE ... PASSWORD '...' to the logs in plain text, and schema
  # history already lives in the migrations in git.

  # Log the text of any query slower than 1 second...
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # ...but not the values bound into it ($1, $2, ...), which are user data.
  # (log_parameter_max_length_on_error already defaults to 0.) Values typed
  # straight into the SQL would still be logged; the API uses bind
  # parameters, so that shouldn't happen.
  parameter {
    name  = "log_parameter_max_length"
    value = "0"
  }

  tags = { Name = var.name }

  # A major version upgrade needs a new family. Build the replacement first,
  # since the old one can't be deleted while the instance still uses it
  # (name_prefix lets both exist at once).
  lifecycle {
    create_before_destroy = true
  }
}

# One per log export, created before the instance, so RDS writes into these
# (with retention) instead of creating its own groups that keep logs forever.
resource "aws_cloudwatch_log_group" "this" {
  #checkov:skip=CKV_AWS_158:Default CloudWatch encryption is enough for slow-query and upgrade logs; a KMS key adds cost and a key policy for a solo project.
  #checkov:skip=CKV_AWS_338:Short retention on purpose: these logs are for debugging, not audit, and storage bills per GB. Set per environment.
  for_each = toset(local.log_exports)

  name              = "/aws/rds/instance/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
}

# --- The database ------------------------------------------------------------

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_157:Multi-AZ is a variable (multi_az). Off in dev to halve the cost; turn on in prod once it has real users (ADR 0010).
  #checkov:skip=CKV_AWS_118:No enhanced monitoring: it needs its own IAM role and bills CloudWatch per instance. Performance Insights covers dev and early prod.
  #checkov:skip=CKV_AWS_354:Performance Insights uses the AWS-managed key. A customer-managed KMS key adds cost and a key policy without changing who can read it.
  #checkov:skip=CKV_AWS_293:Deletion protection is a variable, on by default. Only dev turns it off so its throwaway DB can be torn down cleanly.
  #checkov:skip=CKV2_AWS_30:No statement logging (log_statement) on purpose: it writes CREATE ROLE passwords in plain text. Slow queries are logged without their values instead.
  identifier = var.name

  engine                     = "postgres"
  engine_version             = var.engine_version
  auto_minor_version_upgrade = true

  # Changing engine_version to a new major (18 -> 19) is the deliberate
  # step; without this, RDS rejects it after the new parameter group is
  # already built, leaving the apply half done.
  allow_major_version_upgrade = true
  instance_class              = var.instance_class
  parameter_group_name        = aws_db_parameter_group.this.name

  db_name                             = var.db_name
  username                            = var.master_username
  manage_master_user_password         = true # RDS makes the password and keeps it in Secrets Manager
  iam_database_authentication_enabled = true # lets the app log in with its IAM role later, no password

  storage_type      = "gp3"
  allocated_storage = var.allocated_storage_gb
  storage_encrypted = true # AWS-managed KMS key (aws/rds)

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  port                   = local.port
  multi_az               = var.multi_az
  ca_cert_identifier     = "rds-ca-rsa2048-g1"

  backup_retention_period   = var.backup_retention_days
  copy_tags_to_snapshot     = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately         = var.apply_immediately

  # Performance Insights: a free 7-day history of which queries are slow.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = local.log_exports

  tags = { Name = var.name }

  depends_on = [aws_cloudwatch_log_group.this]
}
