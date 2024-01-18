output "public_ip" {
  description = "Public IP address of bastion host"
  value       = aws_eip.main.public_ip
}
