variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "description" {
  description = "Short text to describe purpose of the database"
  type        = string
}

variable "name" {
  description = "Name of the RDS instance"
  type        = string
}

variable "vpc_id" {
  description = "ID of main VPC"
  type        = string
}

variable "allocated_storage" {
  description = "Storage size of the database"
  type        = string
}

variable "instance_class" {
  description = "Instance class of RDS instance"
  type        = string
}

variable "db_name" {
  description = "Name of database"
  type        = string
}

variable "db_username" {
  description = "Username of master user in database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password of master user in database"
  type        = string
  sensitive   = true
}

variable "subnets" {
  description = "IDs of subnets in which the RDS instance lives in"
  type        = list(string)
}

variable "skip_final_snapshot" {
  description = "Flag for wether or not creating a final snapshot before database deletion"
  type        = bool
}
