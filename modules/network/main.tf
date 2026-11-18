# Network for one environment (ADR 0010).
#
#   public subnets  - can reach the internet through the internet gateway.
#                     The API's Fargate tasks will run here with public IPs
#                     (TSL-18), so no NAT Gateway is needed. Their security
#                     group, not the subnet, keeps the internet out.
#   private subnets - no route to the internet at all. The database lives
#                     here.
#
# One public + one private subnet per AZ.

locals {
  # AZ name => index, e.g. { "us-east-1a" = 0, "us-east-1b" = 1 }. Keying
  # by AZ name keeps resource addresses stable if the list changes.
  #
  # The AZs are listed by the caller, not looked up: a lookup's result can
  # change when AWS adds or retires a zone, which would quietly move
  # subnets on the next apply (checkov CKV_AWS_394).
  az_index = { for i, az in var.availability_zones : az => i }
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:No VPC flow logs yet. They bill per GB to CloudWatch and nothing reviews them on a solo project. Revisit with real users (ADR 0010).
  cidr_block = var.cidr_block

  # Lets resources resolve AWS service names (and RDS endpoints) to
  # addresses inside the VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# AWS gives every VPC a default security group that allows all traffic
# between its members. Taking it over with no rules makes it deny-all, so
# anything accidentally left on it gets nothing.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-unused" }
}

# --- Public side -------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  for_each = local.az_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, each.value) # 10.0.0.0/24, 10.0.1.0/24

  # Nothing gets a public IP just by landing here. Fargate asks for one
  # explicitly (assign_public_ip in TSL-18).
  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-public-${each.key}", Tier = "public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- Private side ------------------------------------------------------------

resource "aws_subnet" "private" {
  for_each = local.az_index

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_block, 8, each.value + 10) # 10.0.10.0/24, 10.0.11.0/24

  tags = { Name = "${var.name}-private-${each.key}", Tier = "private" }
}

# No 0.0.0.0/0 route: only traffic inside the VPC (and to S3, below).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# --- S3 gateway endpoint -----------------------------------------------------

# A free, private route to S3. ECR stores image layers in S3, so container
# pulls use this instead of the internet. Gateway endpoints cost nothing,
# unlike interface endpoints (ADR 0010).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]

  tags = { Name = "${var.name}-s3" }
}

data "aws_region" "current" {}

# --- App security group ------------------------------------------------------

# The API service's security group. Created here, empty, so the database
# can trust it now (only members of this group reach Postgres). TSL-18
# attaches it to the ECS service and adds its rules: inbound from the load
# balancer, outbound HTTPS and Postgres.
resource "aws_security_group" "api" {
  #checkov:skip=CKV2_AWS_5:Not attached yet on purpose. TSL-18 attaches it to the ECS service; the database trusts it today.
  name        = "${var.name}-api"
  description = "Steel Ledger API service (ECS tasks). Rules added in TSL-18."
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${var.name}-api" }
}
