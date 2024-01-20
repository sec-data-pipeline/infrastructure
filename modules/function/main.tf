data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.project}-${var.env}-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  dynamic "inline_policy" {
    for_each = var.policies
    content {
      name   = "${var.project}-${var.env}-${var.name}-${inline_policy.value["name"]}"
      policy = inline_policy.value["policy"]
    }
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "IAM role for the Lambda function ${var.name}"
  }
}

resource "aws_lambda_function" "non_vpc" {
  count         = length(var.vpc_config) == 0 ? 1 : 0 # this lambda resource is not added to vpc
  function_name = "${var.project}-${var.env}-${var.name}"
  package_type  = "Image"
  role          = aws_iam_role.main.arn
  image_uri     = "${var.repo_url}:latest"
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = var.env_variables
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}

data "aws_iam_policy_document" "logging" {
  count = var.logging ? 1 : 0
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "logging" {
  count  = var.logging ? 1 : 0
  name   = "${var.project}-${var.env}-${var.name}-lambda-logging"
  policy = data.aws_iam_policy_document.logging.0.json
}

resource "aws_iam_role_policy_attachment" "logging" {
  count      = var.logging ? 1 : 0
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.logging.0.arn
}

data "aws_iam_policy_document" "vpc" {
  count = length(var.vpc_config) > 0 ? 1 : 0
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "vpc" {
  count  = length(var.vpc_config) > 0 ? 1 : 0
  name   = "${var.project}-${var.env}-${var.name}-assign-vpc"
  policy = data.aws_iam_policy_document.vpc.0.json
}

resource "aws_iam_role_policy_attachment" "vpc" {
  count      = length(var.vpc_config) > 0 ? 1 : 0
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.vpc.0.arn
}

resource "aws_lambda_function" "vpc" {
  count         = length(var.vpc_config) > 0 ? 1 : 0 # this lambda resource is added to vpc
  function_name = "${var.project}-${var.env}-${var.name}"
  package_type  = "Image"
  role          = aws_iam_role.main.arn
  image_uri     = "${var.repo_url}:latest"
  memory_size   = var.memory_size
  timeout       = var.timeout

  environment {
    variables = var.env_variables
  }

  vpc_config {
    subnet_ids         = var.vpc_config["subnet_ids"]
    security_group_ids = var.vpc_config["security_group_ids"]
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}

resource "aws_lambda_event_source_mapping" "main" {
  count            = length(var.trigger) > 0 ? 1 : 0
  event_source_arn = var.trigger["queue_arn"]
  enabled          = true
  function_name    = length(var.vpc_config) > 0 ? aws_lambda_function.vpc.0.arn : aws_lambda_function.non_vpc.0.arn
  batch_size       = 1
}
