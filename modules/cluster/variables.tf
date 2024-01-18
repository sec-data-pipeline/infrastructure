variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "region" {
  description = "Region in which the pipeline operates for the Cloudwatch log group"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets where the services of the cluster live in"
  type        = list(string)
}

variable "tasks" {
  description = "Tasks or services the cluster provisions"
  type        = list(any)
}
