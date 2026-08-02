# ADR 0003: AWS EC2 Mac instance over purchasing hardware

## Status
Accepted

## Context
SwiftUI development requires Xcode, which requires macOS, which wasn't available locally. Three options considered: purchase a Mac (e.g., M4 MacBook Air), short-term cloud rental (MacInCloud/MacStadium), or an AWS EC2 Mac instance provisioned via Terraform.

## Decision
AWS EC2 Mac instance.

## Consequences
No upfront hardware cost, and provisioning via Terraform keeps it consistent with the rest of the project's infra-as-code approach rather than being a separate, unrelated workflow. Trade-off: Apple licensing requires a 24-hour minimum reservation per instance (not built for quick hourly bursts), and real-device debugging isn't possible, Xcode's wired debugger requires the Mac and iPhone to be physically co-located, which a data-center instance can't provide. ARKit work in Epic 2 has no simulator support at all, so that work validates via TestFlight builds on real hardware instead of live Xcode debugging, a slower iteration loop (roughly 20-60 minutes round trip) but a genuinely workable one.
