variable "region" {
  description = "Region where this infrastructure is deployed"
  type        = string
}

variable "env" {
  description = "Environment e.g. prod or dev"
  type        = string
}

variable "db_username" {
  description = "Name of master user in the SEC database"
  type        = string
}

variable "db_password" {
  description = "Password of master user in the SEC database"
  type        = string
}

variable "allowed_ip_addresses" {
  description = "List of allowed IP address ranges e.g. [\"{your IP address}/32\"] to whitlist your IP address"
  type        = list(string)
}

variable "public_ssh_key_file_path" {
  description = "Path to the public SSH file to access the bastion host"
  type        = string
}
