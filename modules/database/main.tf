resource "aws_security_group" "outbound" {
  name        = "${var.project}-${var.env}-egress-database"
  description = "Allows services with this security group to access the RDS instance"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows services with this security group to access the RDS instance"
  }
}

resource "aws_security_group" "inbound" {
  name        = "${var.project}-${var.env}-ingress-database"
  description = "Allows RDS instance to be accessed by services"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows RDS instance to be accessed by services"
  }
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id            = aws_security_group.outbound.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.inbound.id
}

resource "aws_vpc_security_group_ingress_rule" "inbound" {
  security_group_id            = aws_security_group.inbound.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.outbound.id
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project}-${var.env}"
  allocated_storage      = var.allocated_storage
  db_name                = var.db_name
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.instance_class
  username               = var.db_username
  password               = var.db_password
  port                   = var.db_port
  skip_final_snapshot    = var.skip_final_snapshot
  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = [aws_security_group.inbound.id]

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Database to store data retrieved from the SEC"
  }
}

resource "aws_secretsmanager_secret" "main" {
  name                    = "${var.project}-${var.env}-database"
  recovery_window_in_days = 0

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Secrets to access the databse"
  }
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id = aws_secretsmanager_secret.main.id
  secret_string = jsonencode(
    {
      DB_HOST = aws_db_instance.main.endpoint
      DB_PORT = tostring(var.db_port)
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  )
}
