variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "description" {
  description = "Short text to describe purpose of the Lambda function"
  type        = string
}

variable "name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "policies" {
  description = "IAM policies for the Lambda function's IAM role"
  type        = list(map(string))
}

variable "env_variables" {
  description = "Environment variables for in the Lambda Function"
  type        = map(string)
}

variable "vpc_config" {
  description = "Configuration to add the Lambda Function to a VPC"
  type        = map(list(string))
  default     = {}
}

variable "memory_size" {
  description = "Size of allocated memory to Lambda Function"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Time after which the Lambda Function should be stopped"
  type        = number
  default     = 3
}

variable "trigger" {
  description = "Information about resource, which triggers the Lambda function"
  type        = map(string)
  default     = {}
}

variable "logging" {
  description = "Wheter or not this Lambda function shall create and submit logs"
  type        = bool
  default     = false
}
