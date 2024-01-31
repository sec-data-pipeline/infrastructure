resource "aws_sqs_queue" "deadletter" {
  name = "${var.project}-${var.env}-${var.name}-deadletter"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store events of the ${var.name} queue which could not be processed"
  }
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.project}-${var.env}-${var.name}"
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter.arn
    maxReceiveCount     = 4
  })

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store manually produced events"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "main" {
  queue_url = aws_sqs_queue.deadletter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}
