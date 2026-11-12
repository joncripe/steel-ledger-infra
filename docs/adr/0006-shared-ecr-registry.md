# ADR 0006: One shared ECR repository for all environments

## Status
Accepted

## Context
The Vapor API ships as a container image. Each environment (dev/stage/prod) could have its own registry and its own build, or all of them could pull from one registry. Rebuilding for each environment means prod can run an image that was never tested in dev or stage.

## Decision
One ECR repository, `steel-ledger-api`, managed in `bootstrap/` next to the other account-wide resources. CI builds each image once and environments promote the same image by tag ("build once, deploy many").

- `image_tag_mutability = "IMMUTABLE"`, so a tag always points at the same image.
- `scan_on_push = true` for basic vulnerability scanning.
- The lifecycle policy expires only untagged images (after 7 days).

## Consequences
What runs in prod is the exact artifact that was tested earlier, so rollbacks mean redeploying an existing tag.

Trade-offs:
- Every environment shares one retention policy. A "keep the newest N images" rule could expire the image prod is running, so there's no count-based rule on tagged images yet. Tagged retention gets added with TSL-9's tagging convention, excluding release tags.
- Immutable tags can't be re-pushed. A deleted image's tag is gone for good, which is one more reason to retain release tags.
- Every environment's CI role will need pull access here. Push access should be limited to the build pipeline.
