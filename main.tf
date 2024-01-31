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

module "filing_bucket" {
  source = "./modules/bucket"

  project                    = local.project
  env                        = var.env
  name                       = "filing"
  queues                     = ["filing"]
  description                = "Bucket to store the raw SEC filings"
  visibility_timeout_seconds = 500
}

module "statement_bucket" {
  source = "./modules/bucket"

  project     = local.project
  env         = var.env
  name        = "statement"
  queues      = []
  description = "Bucket to store various statements of filings"
}

module "statement_queue" {
  source = "./modules/queue"

  project                    = local.project
  env                        = var.env
  name                       = "statement"
  visibility_timeout_seconds = 500
}

module "extractor_repository" {
  source = "./modules/repository"

  project     = local.project
  env         = var.env
  name        = "extractor"
  description = "Image to spin up containers which extract the filings"
}

module "cluster" {
  source = "./modules/cluster"

  project            = local.project
  env                = var.env
  region             = var.region
  private_subnet_ids = module.network.private_subnet_ids
  name               = "extractor"
  description        = "Extracts the filing data from the SEC"
  repo_url           = module.extractor_repository.url
  cpu                = 256
  memory             = 512
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
      value = module.filing_bucket.id
    }
  ]
  task_policies = concat(
    module.filing_bucket.write_access_policies,
    module.database.secrets_access_policies
  )
}

module "slicer_repository" {
  source = "./modules/repository"

  project     = local.project
  env         = var.env
  name        = "slicer"
  description = "Image to spin up containers which slice the financial statements out of the filing"
}

module "slicer_function" {
  source = "./modules/function"

  project     = local.project
  env         = var.env
  name        = "slicer"
  description = "Lambda function to slice various statements out of a filing"
  repo_url    = module.slicer_repository.url
  timeout     = 300
  memory_size = 2048
  logging     = true
  trigger = {
    queue_arn = module.filing_bucket.queue_arns[0]
  }
  env_variables = {
    REGION           = var.region
    FILING_BUCKET    = module.filing_bucket.id
    FILING_QUEUE     = module.filing_bucket.queue_urls[0]
    STATEMENT_BUCKET = module.statement_bucket.id
    STATEMENT_QUEUE  = module.statement_queue.url
  }
  policies = concat(
    module.filing_bucket.read_access_policies,
    module.statement_bucket.write_access_policies,
    [module.statement_queue.producer_policy]
  )
}

module "loader_repository" {
  source = "./modules/repository"

  project     = local.project
  env         = var.env
  name        = "loader"
  description = "Image to spin up containers which load the financial statements into the database"
}

module "loader_function" {
  source = "./modules/function"

  project     = local.project
  env         = var.env
  name        = "loader"
  description = "Lambda function to load various statements into the database"
  repo_url    = module.loader_repository.url
  timeout     = 300
  memory_size = 2048
  logging     = true
  vpc_config = {
    subnet_ids = module.network.private_subnet_ids
    security_group_ids = [
      module.network.default_security_group_id,
      module.database.security_group_id
    ]
  }
  trigger = {
    queue_arn = module.statement_queue.arn
  }
  env_variables = {
    REGION           = var.region
    SECRETS          = module.database.secrets_arn
    STATEMENT_BUCKET = module.statement_bucket.id
    STATEMENT_QUEUE  = module.statement_queue.url
  }
  policies = concat(
    module.statement_bucket.read_access_policies,
    module.database.secrets_access_policies,
    [module.statement_queue.consumer_policy]
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
  bucket_arns          = [module.filing_bucket.arn, module.statement_bucket.arn]
}
