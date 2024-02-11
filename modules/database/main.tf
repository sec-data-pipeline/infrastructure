locals {
  engine         = "postgres"
  engine_family  = "POSTGRESQL"
  engine_version = "15.3"
  port           = 5432
}

resource "aws_security_group" "proxy" {
  name        = "${var.project}-${var.env}-${var.name}-rds-proxy"
  description = "Allows RDS proxy to access the RDS instance"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows RDS proxy to access the RDS instance"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-${var.env}-${var.name}-rds"
  description = "Allows RDS instance to be accessed by RDS proxy"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows RDS instance to be accessed by RDS proxy"
  }
}

resource "aws_security_group" "external" {
  name        = "${var.project}-${var.env}-${var.name}-external"
  description = "Allows services to access the RDS proxy"
  vpc_id      = var.vpc_id

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Allows services to access the RDS proxy"
  }
}

resource "aws_vpc_security_group_egress_rule" "proxy" {
  security_group_id            = aws_security_group.proxy.id
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_ingress_rule" "proxy" {
  security_group_id            = aws_security_group.proxy.id
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.external.id
}

resource "aws_vpc_security_group_ingress_rule" "rds" {
  security_group_id            = aws_security_group.rds.id
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.proxy.id
}

resource "aws_vpc_security_group_egress_rule" "external" {
  security_group_id            = aws_security_group.external.id
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.proxy.id
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-${var.env}-${var.name}-database"
  description = "Groups subnets for RDS instance"
  subnet_ids  = var.subnets

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Groups subnets for RDS instance"
  }
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project}-${var.env}-${var.name}"
  allocated_storage      = var.allocated_storage
  db_name                = var.db_name
  engine                 = local.engine
  engine_version         = local.engine_version
  instance_class         = var.instance_class
  username               = var.db_username
  password               = var.db_password
  port                   = local.port
  skip_final_snapshot    = var.skip_final_snapshot
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}

resource "aws_secretsmanager_secret" "proxy" {
  name                    = "${var.project}-${var.env}-${var.name}-rds-proxy"
  recovery_window_in_days = 0

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Secrets for the RDS proxy to access the database"
  }
}

resource "aws_secretsmanager_secret_version" "proxy" {
  secret_id = aws_secretsmanager_secret.proxy.id
  secret_string = jsonencode(
    {
      username             = var.db_username
      password             = var.db_password
      engine               = local.engine
      host                 = aws_db_instance.main.address
      port                 = tostring(local.port)
      dbInstanceIdentifier = aws_db_instance.main.id
    }
  )
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = [aws_secretsmanager_secret.proxy.arn]
  }
}

resource "aws_iam_role" "proxy" {
  name               = "${var.project}-${var.env}-${var.name}-rds-proxy"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  inline_policy {
    name   = "read-access-database-secrets"
    policy = data.aws_iam_policy_document.read_secrets.json
  }
}

resource "aws_db_proxy" "main" {
  name                   = "${var.project}-${var.env}-${var.name}"
  debug_logging          = false
  engine_family          = local.engine_family
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.proxy.arn
  vpc_security_group_ids = [aws_security_group.proxy.id]
  vpc_subnet_ids         = var.subnets

  auth {
    auth_scheme = "SECRETS"
    description = "RDS proxy authentificates through secrets from RDS' SecretsManager"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.proxy.arn
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "RDS proxy to manage connections of RDS instance"
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "main" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
}

resource "aws_secretsmanager_secret" "external" {
  name                    = "${var.project}-${var.env}-${var.name}-rds-external"
  recovery_window_in_days = 0

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Secrets for services to access the RDS proxy"
  }
}

resource "aws_secretsmanager_secret_version" "external" {
  secret_id = aws_secretsmanager_secret.external.id
  secret_string = jsonencode(
    {
      DB_HOST = aws_db_proxy.main.endpoint
      DB_PORT = tostring(local.port)
      DB_NAME = var.db_name
      DB_USER = var.db_username
      DB_PASS = var.db_password
    }
  )
}
