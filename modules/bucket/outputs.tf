output "arn" {
  description = "ARN of the S3 bucket to access it"
  value       = aws_s3_bucket.main.arn
}

output "id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "queue_arns" {
  description = "ARNs of the queues"
  value       = aws_sqs_queue.main.*.arn
}

output "queue_urls" {
  description = "URLs to the queues"
  value       = aws_sqs_queue.main.*.url
}

output "read_access_policies" {
  description = "IAM policies for read access to resources created in this module as intended"
  value = [
    {
      name = "read-access-${var.name}-bucket"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["s3:GetObject"]
            Effect   = "Allow"
            Resource = "${aws_s3_bucket.main.arn}/*"
          },
        ]
      })
    },
    {
      name = "consumer-access-${var.name}-queue"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
            Effect   = "Allow"
            Resource = aws_sqs_queue.main.*.arn
          },
        ]
      })
    }
  ]
}

output "write_access_policies" {
  description = "IAM policies for write access to resources created in this module as intended"
  value = [
    {
      name = "write-access-${var.name}-bucket"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action   = ["s3:PutObject"]
            Effect   = "Allow"
            Resource = aws_s3_bucket.main.arn
          },
        ]
      })
    },
  ]
}
