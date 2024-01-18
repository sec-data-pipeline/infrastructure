output "id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private.*.id
}

output "private_subnet_group_name" {
  description = "Name of private subnet group"
  value       = aws_db_subnet_group.private.name
}

output "default_security_group_id" {
  description = "ID of default security group which allows internet access"
  value       = aws_security_group.main.id
}
