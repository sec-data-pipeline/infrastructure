variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the whole VPC"
  type        = string
}

variable "public_cidrs" {
  description = "List of CIDR blocks of public subnets"
  type        = list(string)
}

variable "private_cidrs" {
  description = "List of CIDR blocks of private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones where the subnets live in"
  type        = list(string)
}
