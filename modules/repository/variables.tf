variable "project" {
  description = "Name of the project, which is also part of the naming scheme of the resources"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "description" {
  description = "Short text to describe purpose of the containers that are spin up from images in this repo"
  type        = string
}

variable "name" {
  description = "Name of the repository"
  type        = string
}
