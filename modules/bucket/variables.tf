variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "description" {
  description = "Short text to describe purpose of this S3 bucket"
  type        = string
}

variable "name" {
  description = "Name of the S3 bucket and SQS queue"
  type        = string
}

variable "queues" {
  description = "List of queues which will hold CreateObject events of it's S3 bucket"
  type        = list(string)
  default     = []
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before the queue rejects it"
  type        = number
  default     = 262144 # 256 KiB
}

variable "message_retention_seconds" {
  description = "The number of seconds the queue retains a message"
  type        = number
  default     = 345600 # 4 days
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue"
  type        = number
  default     = 120 # 2 minutes
}
