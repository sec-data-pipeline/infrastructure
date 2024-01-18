locals {
  project = "sec-data-pipeline"
}

module "network" {
  source = "./modules/network"

  project            = local.project
  env                = var.env
  vpc_cidr           = "10.0.0.0/16"
  public_cidrs       = ["10.0.1.0/24"]
  private_cidrs      = ["10.0.2.0/24", "10.0.3.0/24"]
  availability_zones = ["${var.region}a", "${var.region}b"]
}

module "database" {
  source = "./modules/database"

  project             = local.project
  env                 = var.env
  vpc_id              = module.network.id
  subnet_group_name   = module.network.private_subnet_group_name
  allocated_storage   = 20
  instance_class      = "db.t3.micro"
  db_engine           = "postgres"
  db_engine_version   = "15.3"
  db_port             = 5432
  db_name             = "sec"
  db_username         = var.db_username
  db_password         = var.db_password
  skip_final_snapshot = true
}

module "archive_bucket" {
  source = "./modules/bucket"

  project     = local.project
  env         = var.env
  name        = "archive"
  description = "Bucket to store the raw the SEC filings"
}

module "balance_bucket" {
  source = "./modules/bucket"

  project     = local.project
  env         = var.env
  name        = "balance"
  description = "Bucket to store the balance sheets of filings"
}

module "cashflow_bucket" {
  source = "./modules/bucket"

  project     = local.project
  env         = var.env
  name        = "cashflow"
  description = "Bucket to store the cash flow statements of filings"
}

module "cluster" {
  source = "./modules/cluster"

  project            = local.project
  env                = var.env
  region             = var.region
  private_subnet_ids = module.network.private_subnet_ids
  tasks = [
    {
      name        = "extractor"
      description = "Extracts the filing data from the SEC"
      cpu         = 256
      memory      = 512
      security_groups = [
        module.network.default_security_group_id,
        module.database.security_group_id
      ]
      env_variables = [
        {
          name  = "REGION"
          value = var.region
        },
        {
          name  = "SECRETS_ARN"
          value = module.database.secrets_arn
        },
        {
          name  = "ARCHIVE_BUCKET"
          value = module.archive_bucket.id
        }
      ]
      policies = concat(
        module.archive_bucket.write_access_policies,
        module.database.secrets_access_policies
      )
    }
  ]
}

module "slicer_function" {
  source = "./modules/function"

  project     = local.project
  env         = var.env
  name        = "slicer"
  description = "Lambda function to slice the financial statements out of a filing"
  timeout     = 10
  memory_size = 512
  logging     = true
  trigger = {
    queue_arn = module.archive_bucket.queue_arn
  }
  env_variables = {
    REGION          = var.region
    ARCHIVE_BUCKET  = module.archive_bucket.id
    ARCHIVE_QUEUE   = module.archive_bucket.queue_url
    BALANCE_BUCKET  = module.balance_bucket.id
    CASHFLOW_BUCKET = module.cashflow_bucket.id
  }
  policies = concat(
    module.archive_bucket.read_access_policies,
    module.balance_bucket.write_access_policies,
    module.cashflow_bucket.write_access_policies
  )
}

module "balance_function" {
  source = "./modules/function"

  project     = local.project
  env         = var.env
  name        = "balance-sheet-loader"
  description = "Lambda function to parse balance sheets and store the data in the database"
  vpc_config = {
    subnet_ids = module.network.private_subnet_ids
    security_group_ids = [
      module.network.default_security_group_id,
      module.database.security_group_id
    ]
  }
  trigger = {
    queue_arn = module.archive_bucket.queue_arn
  }
  env_variables = {
    REGION         = var.region
    SECRETS        = module.database.secrets_arn
    BALANCE_QUEUE  = module.balance_bucket.queue_url
    BALANCE_BUCKET = module.balance_bucket.id
  }
  policies = concat(
    module.balance_bucket.read_access_policies,
    module.database.secrets_access_policies
  )
}

module "cashflow_function" {
  source = "./modules/function"

  project     = local.project
  env         = var.env
  name        = "cash-flow-statement-loader"
  description = "Lambda function to parse cash flow statements and store the data in the database"
  vpc_config = {
    subnet_ids = module.network.private_subnet_ids
    security_group_ids = [
      module.network.default_security_group_id,
      module.database.security_group_id
    ]
  }
  trigger = {
    queue_arn = module.archive_bucket.queue_arn
  }
  env_variables = {
    REGION          = var.region
    SECRETS         = module.database.secrets_arn
    CASHFLOW_QUEUE  = module.cashflow_bucket.queue_url
    CASHFLOW_BUCKET = module.cashflow_bucket.id
  }
  policies = concat(
    module.cashflow_bucket.read_access_policies,
    module.database.secrets_access_policies
  )
}

module "bastion_host" {
  source = "./modules/bastion"

  project              = local.project
  env                  = var.env
  vpc_id               = module.network.id
  subnet_id            = module.network.public_subnet_ids[0]
  db_security_group_id = module.database.security_group_id
  instance_type        = "t2.micro"
  public_ssh_key       = file(var.public_ssh_key_file_path) # path to public SSH key for bastion host access
  allowed_ip_addresses = var.allowed_ip_addresses
  secrets_arn          = module.database.secrets_arn
  bucket_arns          = [module.archive_bucket.arn, module.balance_bucket.arn, module.cashflow_bucket.arn]
}
