output "ip" {
  description = "IP address assigned to the bastion host"
  value       = module.bastion_host.public_ip
}

output "endpoint" {
  description = "Host endpoint of RDS instance"
  value       = module.database.endpoint
}
