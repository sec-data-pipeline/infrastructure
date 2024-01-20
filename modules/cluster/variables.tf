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

variable "name" {
  description = "Name of the task in the cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets where the services of the cluster live in"
  type        = list(string)
}

variable "repo_url" {
  description = "URL of the repository from which the Fargate task pulls it's image from"
  type        = string
}

variable "task_policies" {
  description = "IAM policies for the Fargate task's IAM role"
  type        = list(map(string))
}

variable "cpu" {
  description = "CPU of the Fargate task in the ECS cluster"
  type        = number
}

variable "memory" {
  description = "Memory of the Fargate task in the ECS cluster"
  type        = number
}

variable "env_variables" {
  description = "Environment variables for the Fargate task in the ECS cluser"
  type        = list(map(string))
}

variable "description" {
  description = "Description of the task and service in the ECS cluser"
  type        = string
}

variable "security_groups" {
  description = "Security group IDs of the service in the ECS cluster"
  type        = list(string)
}
