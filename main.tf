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
  name                = "sec"
  description         = "Stores data about SEC filings"
  vpc_id              = module.network.id
  subnets             = module.network.private_subnet_ids
  allocated_storage   = 20
  instance_class      = "db.t3.micro"
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
  queues      = ["archive"]
  description = "Bucket to store the raw SEC filings"
}

module "table_bucket" {
  source = "./modules/bucket"

  project     = local.project
  env         = var.env
  name        = "table"
  description = "Bucket to store the table of the filings"
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
      name  = "SECRETS"
      value = module.database.secrets_arn
    },
    {
      name  = "ARCHIVE_BUCKET"
      value = module.archive_bucket.id
    }
  ]
  task_policies = concat(
    module.archive_bucket.write_access_policies,
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

  project        = local.project
  env            = var.env
  name           = "slicer"
  description    = "Lambda function to slice the tables out of the filings"
  repo_url       = module.slicer_repository.url
  timeout        = 15
  memory_size    = 512
  logging        = true
  trigger = {
    queue_arn = module.archive_bucket.queue_arns[0]
  }
  vpc_config = {
    subnet_ids         = module.network.private_subnet_ids
    security_group_ids = [module.network.default_security_group_id, module.database.security_group_id]
  }
  env_variables = {
    REGION         = var.region
    ARCHIVE_BUCKET = module.archive_bucket.id
    QUEUE          = module.archive_bucket.queue_urls[0]
    TABLE_BUCKET   = module.table_bucket.id
    SECRETS        = module.database.secrets_arn
  }
  policies = concat(
    module.database.secrets_access_policies,
    module.archive_bucket.read_access_policies,
    module.table_bucket.write_access_policies
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
}
