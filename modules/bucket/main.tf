resource "random_string" "main" {
  length  = 5
  special = false
  upper   = false
}

resource "aws_s3_bucket" "main" {
  bucket        = "${var.project}-${var.env}-${var.name}-${random_string.main.result}"
  force_destroy = true

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "public-read-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.main,
    aws_s3_bucket_public_access_block.main,
  ]
}

data "aws_iam_policy_document" "bucket" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "lambda.amazonaws.com"]
    }

    actions = ["s3:*"]

    resources = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = data.aws_iam_policy_document.bucket.json
}

data "aws_iam_policy_document" "queue" {
  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:${var.project}-${var.env}-${var.name}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

resource "aws_sqs_queue" "deadletter" {
  name = "${var.project}-${var.env}-${var.name}-deadletter"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store the create object events of the ${var.name} bucket"
  }
}

resource "aws_sqs_queue" "main" {
  name                       = "${var.project}-${var.env}-${var.name}"
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = 120
  policy                     = data.aws_iam_policy_document.queue.json

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter.arn
    maxReceiveCount     = 4
  })

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store the create object events of the ${var.name} bucket"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "main" {
  queue_url = aws_sqs_queue.deadletter.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  queue {
    queue_arn = aws_sqs_queue.main.arn
    events    = ["s3:ObjectCreated:*"]
  }
}
