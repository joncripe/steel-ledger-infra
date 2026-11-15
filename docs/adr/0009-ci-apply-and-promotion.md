# ADR 0009: Auto-apply dev, promote stage and prod by hand

## Status
Accepted

## Context
TSL-19 adds apply to CI. The first plan was to apply every environment on merge to main, with stage and prod pausing for a required reviewer. On a solo project, that means every merge leaves approval prompts waiting for changes that may not be ready to promote yet. Approving your own change also adds a click without adding a second pair of eyes.

`environments/dev` was also the EC2 Mac. CI can't apply it (a mac2.metal host has a 24-hour minimum bill), and Mac work may be a long way off while web and API work happens now. So dev needed to be usable without the Mac.

## Decision
- **The Mac gets its own root.** The Mac moved to `environments/dev-mac` and is still off in CI (`plan: false, apply: false`) until TSL-44. Its state key (`dev/ec2-mac-dev.tfstate`) didn't change, so nothing moved in AWS.
- **dev, stage and prod are normal roots.** `environments/{dev,stage,prod}` started empty (backend and provider only, state at `<env>/terraform.tfstate`), so the pipeline could be proven end to end before real resources exist.
- **Each root has an apply mode** in `.github/terraform-roots.json`:
  - `"auto"`: applied on every merge to main (dev), and on demand from **Run workflow** (for example, to re-apply after a manual change in the console).
  - `"manual"`: applied only from **Run workflow** on `Terraform apply`, which promotes whatever is on main (stage, prod).
  - `false`: never applied by CI (bootstrap, dev-mac).
- **GitHub Environments (`dev`, `stage`, `prod`) are limited to `main` and have no required reviewers.** The apply roles only trust their own `environment:<env>` (ADR 0008), so the Environment's branch rule is what stops unmerged code from being applied. Clicking Run is the approval.
- **One apply per environment at a time.** The concurrency group is per environment, with `cancel-in-progress: false`, so an apply is never stopped mid-write.
- **The public repo never sees plan details.** PR comments, logs and job summaries show only the summary line, changed resource addresses and error headlines.

## Consequences
dev always matches main. stage and prod change only when you decide to promote them, and the run records who promoted what, and when. Adding an environment means adding a folder and one entry in `terraform-roots.json`, plus the dropdown option for a manual root.

Trade-offs:
- No second reviewer on stage or prod. Add required reviewers to those Environments once someone else joins the project.
- A promotion applies the latest main, not a specific earlier commit. Rolling back means reverting on main and promoting again.
- The empty roots have no state file until their first real resource, so the first runs show the lock, role and Environment working, but not a state write.
- The "summary only" filtering is copied into both the PR and apply workflows. Change both together.
