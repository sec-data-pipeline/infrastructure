output "name" {
  description = "Name of the Lambda function"
  value       = "${var.project}-${var.env}-${var.name}"
}

output "arn" {
  description = "ARN of the Lambda function"
  value       = length(var.vpc_config) == 0 ? aws_lambda_function.non_vpc.0.arn : aws_lambda_function.vpc.0.arn
}
