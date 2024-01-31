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

data "aws_iam_policy_document" "s3_queue" {
  count = length(var.queues) > 1 || length(var.queues) == 0 ? 0 : 1

  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:${var.project}-${var.env}-${var.queues[0]}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

data "aws_iam_policy_document" "fanout" {
  count = length(var.queues) > 1 && length(var.queues) != 0 ? 1 : 0
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = ["arn:aws:sns:*:*:${var.project}-${var.env}-${var.name}-sqs-fanout"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.main.arn]
    }
  }
}

resource "aws_sns_topic" "fanout" {
  count  = length(var.queues) > 1 && length(var.queues) != 0 ? 1 : 0
  name   = "${var.project}-${var.env}-${var.name}-sqs-fanout"
  policy = data.aws_iam_policy_document.fanout[0].json

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "SNS topic to fanout the S3 bucket CreateObject event of ${var.name} to multiple SQS queues"
  }
}

data "aws_iam_policy_document" "sns_queue" {
  count = length(var.queues) > 1 && length(var.queues) != 0 ? length(var.queues) : 0

  statement {
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["sqs:SendMessage"]
    resources = ["arn:aws:sqs:*:*:${var.project}-${var.env}-${var.queues[count.index]}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.fanout[0].arn]
    }
  }
}

resource "aws_sqs_queue" "deadletter" {
  count = length(var.queues)
  name  = "${var.project}-${var.env}-${var.queues[count.index]}-deadletter"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store the create object events of the ${var.name} bucket which could not be processed"
  }
}

resource "aws_sqs_queue" "main" {
  count                      = length(var.queues)
  name                       = "${var.project}-${var.env}-${var.queues[count.index]}"
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  policy                     = length(var.queues) > 1 ? data.aws_iam_policy_document.sns_queue[count.index].json : data.aws_iam_policy_document.s3_queue[0].json

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[count.index].arn
    maxReceiveCount     = 4
  })

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Queue to store the create object events of the ${var.name} bucket"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "main" {
  count     = length(var.queues)
  queue_url = aws_sqs_queue.deadletter[count.index].id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.main[count.index].arn]
  })
}

resource "aws_sns_topic_subscription" "main" {
  count                = length(var.queues) > 1 ? length(var.queues) : 0
  protocol             = "sqs"
  raw_message_delivery = true
  topic_arn            = aws_sns_topic.fanout[0].arn
  endpoint             = aws_sqs_queue.main[count.index].arn
}

resource "aws_s3_bucket_notification" "topic" {
  count  = length(var.queues) > 1 && length(var.queues) != 0 ? 1 : 0
  bucket = aws_s3_bucket.main.id

  topic {
    topic_arn = aws_sns_topic.fanout[0].arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_s3_bucket_notification" "queue" {
  count  = length(var.queues) > 1 ? 0 : 1
  bucket = aws_s3_bucket.main.id

  queue {
    queue_arn = aws_sqs_queue.main[0].arn
    events    = ["s3:ObjectCreated:*"]
  }
}
