variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "vpc_id" {
  description = "ID of main VPC"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID of EC2 instance (bastion host)"
  type        = string
}

variable "db_security_group_id" {
  description = "ID of security group to access database"
  type        = string
}

variable "instance_type" {
  description = "Instance class of EC2 instance (bastion host)"
  type        = string
}

variable "public_ssh_key" {
  description = "Public key for SSH tunnel to EC2 instance (bastion host)"
  type        = string
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses that are allowed to SSH tunnel to EC2 instance (bastion host)"
  type        = list(string)
}

variable "secrets_arn" {
  description = "ARN of the secrets to be accessed"
  type        = string
}

variable "bucket_arns" {
  description = "ARNs of the S3 buckets this bastion host can access"
  type        = list(string)
}
