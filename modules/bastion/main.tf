data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = [var.secrets_arn]
  }
}

data "aws_iam_policy_document" "access_bucket" {
  statement {
    actions = ["s3:*"]

    resources = concat(var.bucket_arns, ["${var.bucket_arns[0]}/*", "${var.bucket_arns[1]}/*"])
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.project}-${var.env}-bastion-host"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  inline_policy {
    name   = "${var.project}-${var.env}-bastion-host-access-secrets"
    policy = data.aws_iam_policy_document.read_secrets.json
  }

  inline_policy {
    name   = "${var.project}-${var.env}-bastion-host-access-bucket"
    policy = data.aws_iam_policy_document.access_bucket.json
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "IAM role for bastion host to read secrets and access S3 bucket"
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.project}-${var.env}-bastion-host"
  role = aws_iam_role.main.name

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Instance profile to attach IAM role to bastion host"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.project}-${var.env}-bastion-host"
  description = "Allow SSH tunnel connection to bastion host"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "SSH access to bastion host"
  }
}

resource "aws_vpc_security_group_ingress_rule" "main" {
  count             = length(var.allowed_ip_addresses)
  security_group_id = aws_security_group.main.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = element(var.allowed_ip_addresses, count.index)
}

resource "aws_vpc_security_group_egress_rule" "main" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_network_interface" "main" {
  subnet_id       = var.subnet_id
  security_groups = [var.db_security_group_id, aws_security_group.main.id]

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Network interface of bastion host"
  }
}

resource "aws_eip" "main" {
  domain            = "vpc"
  network_interface = aws_network_interface.main.id
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project}-${var.env}-bastion-host"
  public_key = var.public_ssh_key
}

resource "aws_instance" "main" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = aws_key_pair.main.id
  iam_instance_profile = aws_iam_instance_profile.main.name

  network_interface {
    network_interface_id = aws_network_interface.main.id
    device_index         = 0
  }

  tags = {
    Name        = "${var.project}-${var.env}-bastion-host"
    Project     = var.project
    Environment = var.env
    Description = "Bastion host as entrypoint to database from public internet"
  }
}
