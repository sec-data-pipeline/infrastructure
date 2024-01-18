output "security_group_id" {
  description = "ID of security group which is allowed to access RDS instance"
  value       = aws_security_group.outbound.id
}

output "id" {
  description = "ID of RDS instance"
  value       = aws_db_instance.main.id
}

output "arn" {
  description = "ARN of RDS instance"
  value       = aws_db_instance.main.arn
}

output "endpoint" {
  description = "Host endpoint of RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "secrets_arn" {
  description = "ARN of the secrets to access the database"
  value       = aws_secretsmanager_secret.main.arn
}

output "secrets_access_policies" {
  description = "IAM policies for read access to secrets of the database"
  value = [
    {
      name = "read-access-database-secrets"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["secretsmanager:GetSecretValue"]
            Effect   = "Allow"
            Resource = aws_secretsmanager_secret.main.arn
          },
        ]
      })
    }
  ]
}
