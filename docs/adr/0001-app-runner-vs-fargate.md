# ADR 0001: App Runner over Fargate for Vapor compute

## Status
Accepted

## Context
Vapor needs a container host on AWS. Two real options: AWS App Runner (fully managed, minimal Terraform) or ECS Fargate (serverless containers, but requires provisioning cluster, task definition, service, ALB, and VPC networking directly).

## Decision
App Runner.

## Consequences
Fargate would demonstrate more Terraform surface area (VPC, ALB, ECS task defs), which has real interview value, but costs meaningfully more setup time (roughly 6-10 hours for a first-time AWS Fargate deployment vs. 1-2 for App Runner) for infrastructure depth that isn't the actual point of this project. This project's differentiator is the app itself (FitMatch, overlap checking), not infra-engineer-level AWS work, so the simpler, faster option was the right trade.
