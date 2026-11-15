provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tf_state" {
  #checkov:skip=CKV2_AWS_62:Event notifications have no consumer; nothing reacts to state writes.
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is enough here. Access is controlled by IAM and the CI guardrails (ADR 0008); a KMS key adds cost and a key policy to manage.
  #checkov:skip=CKV_AWS_144:No cross-region replica. Versioning + prevent_destroy cover mistakes; losing the whole region is handled by ADR 0007's manual recovery. Revisit if prod needs it.
  #checkov:skip=CKV_AWS_18:No access logging. It needs a second log bucket (which checkov would flag too) for a one-person project. Revisit when more people or CI roles touch state.
  bucket = var.state_bucket_name

  # This bucket holds every environment's Terraform state. Losing it
  # loses the source of truth for what's actually deployed -- accidental
  # destroy is the one mistake this config actively guards against.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "steel-ledger"
    Purpose   = "terraform-state"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning keeps every old copy of every state file forever. Trim the old
# copies, but always keep the 10 most recent per file, so a rarely-changed
# state (like bootstrap) never loses its rollback history.
resource "aws_s3_bucket_lifecycle_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    id     = "trim-old-state-versions"
    status = "Enabled"

    filter {} # whole bucket

    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Each apply's .tflock is deleted afterward, leaving a delete marker.
  # Clean those up once nothing is left behind them.
  rule {
    id     = "clean-delete-markers"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
    }
  }

  # Versioning must be on before noncurrent-version rules mean anything.
  depends_on = [aws_s3_bucket_versioning.tf_state]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}