resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.env}"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Cluster to perform extraction task for the data pipeline workflow"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.project}-${var.env}-${var.name}"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Cloudwatch log group for ${var.name} task in the ECS cluster"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.project}-${var.env}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Execution role for ECS cluster task to pull images"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "task" {
  name               = "${var.project}-${var.env}-ecs-task-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  dynamic "inline_policy" {
    for_each = var.task_policies
    content {
      name   = "${var.project}-${var.env}-${var.name}-${inline_policy.value["name"]}"
      policy = inline_policy.value["policy"]
    }
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "IAM role for the task ${var.name} in the ECS cluster"
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project}-${var.env}-${var.name}"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  container_definitions = jsonencode([
    {
      name        = "${var.project}-${var.env}-${var.name}"
      image       = var.repo_url
      environment = var.env_variables
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main.id
          awslogs-region        = var.region
          awslogs-stream-prefix = "cluster"
        }
      }
    }
  ])

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}

resource "aws_ecs_service" "main" {
  name                 = "${var.project}-${var.env}-${var.name}"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.main.arn
  launch_type          = "FARGATE"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    assign_public_ip = false
    security_groups  = var.security_groups
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}
