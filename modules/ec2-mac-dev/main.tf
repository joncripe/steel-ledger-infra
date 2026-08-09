resource "aws_ec2_host" "mac_dev" {
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  auto_placement    = "on"
  host_recovery     = "off"

  tags = {
    Name        = "${var.project_name}-${var.environment}-mac-host"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "mac_dev" {
  name        = "${var.project_name}-${var.environment}-mac-dev-sg"
  description = "SSH-only access to the EC2 Mac dev instance. VNC (5900) is reached exclusively via SSH tunnel."
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH from the allowed dev IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mac-dev-sg"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

locals {
  subnet_id = coalesce(var.subnet_id, tolist(data.aws_subnets.in_az.ids)[0])
}

resource "aws_instance" "mac_dev" {
  ami           = data.aws_ami.macos.id
  instance_type = var.instance_type

  # tenancy=host + host_id pins this instance to the Dedicated Host --
  # required for all EC2 Mac instances, they cannot run on shared tenancy.
  tenancy   = "host"
  host_id   = aws_ec2_host.mac_dev.id
  subnet_id = local.subnet_id

  vpc_security_group_ids      = [aws_security_group.mac_dev.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type            = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mac-dev"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}