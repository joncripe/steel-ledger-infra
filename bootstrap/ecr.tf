# Container registry for the Vapor API image (steel-ledger-api).
#
# Lives in bootstrap/ because one registry serves every environment: CI
# builds an image once, and dev/stage/prod deploy that same image by tag.

resource "aws_ecr_repository" "api" {
  name = "steel-ledger-api"

  # A tag, once pushed, always points at the same image. CI tags by git
  # SHA, so "what's running in prod" is never ambiguous.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project   = "steel-ledger"
    ManagedBy = "terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images (failed or superseded builds) after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      # No count-based rule on tagged images yet: dev, stage and prod share
      # this registry, so "keep the newest N" could expire the image prod is
      # running. Tagged retention waits for TSL-9's tagging convention, so
      # release tags can be excluded.
    ]
  })
}
