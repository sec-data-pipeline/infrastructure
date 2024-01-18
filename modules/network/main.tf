resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.project}-${var.env}-main-vpc"
    Project     = var.project
    Environment = var.env
    Description = "Main VPC of the service"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_cidrs)
  cidr_block        = element(var.public_cidrs, count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Public subnet of the VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Public subnet internet access"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Route table of public subnet to Internet Gateway"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "main" {
  domain = "vpc"
}

resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.main.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "NAT Gateway for internet access of the private subnets"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_cidrs)
  cidr_block        = element(var.private_cidrs, count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Private subnet of the VPC"
  }
}

resource "aws_db_subnet_group" "private" {
  name        = "${var.project}-${var.env}-database"
  description = "Groups private subnets for RDS instance"
  subnet_ids  = aws_subnet.private.*.id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Groups private subnets for RDS instance"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private.id
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Route table of private subnet"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

# setting default route table of VPC
resource "aws_main_route_table_association" "main" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "main" {
  name        = "${var.project}-${var.env}-default"
  description = "Allows resources to access the internet"
  vpc_id      = aws_vpc.main.id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows resources to access the internet"
  }
}

resource "aws_vpc_security_group_egress_rule" "main" {
  security_group_id = aws_security_group.main.id
  ip_protocol       = -1
  cidr_ipv4         = "0.0.0.0/0"
}
