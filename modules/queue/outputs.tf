output "arn" {
  description = "ARN of the queue"
  value       = aws_sqs_queue.main.arn
}

output "url" {
  description = "URL of the queue"
  value       = aws_sqs_queue.main.url
}

output "producer_policy" {
  description = "IAM policy for the producer to produce events for the queue"
  value = {
    name = "producer-${var.name}-queue"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["sqs:SendMessage"]
          Effect   = "Allow"
          Resource = aws_sqs_queue.main.arn
        },
      ]
    })
  }
}

output "consumer_policy" {
  description = "IAM policy for the consumer to consume events of the queue"
  value = {
    name = "consumer-${var.name}-queue"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
          Effect   = "Allow"
          Resource = aws_sqs_queue.main.arn
        },
      ]
    })
  }
}
