output "url" {
  description = "URL of the repository to access it"
  value       = aws_ecr_repository.main.repository_url
}
