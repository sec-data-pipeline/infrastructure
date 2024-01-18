terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.21.0"
    }
  }

  backend "s3" {
    bucket = "stock-scoring-terraform-states20231218192758240200000001"
    key    = "sec-data-pipeline-dev-state"
    region = "eu-central-1"
  }
}
