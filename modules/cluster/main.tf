resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.env}"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Cluster to perform various tasks for the data pipeline workflow"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  count = length(var.tasks)
  name  = "${var.project}-${var.env}-${var.tasks[count.index].name}"

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Cloudwatch log group for ${var.tasks[count.index].name} task in the ECS cluster"
  }
}

resource "aws_ecr_repository" "main" {
  count                = length(var.tasks)
  name                 = "${var.project}-${var.env}-${var.tasks[count.index].name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "Image for the ${var.tasks[count.index].name} cluster service to execute"
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
    Description = "Execution role for ECS cluster tasks to pull images"
  }
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "task" {
  count              = length(var.tasks)
  name               = "${var.project}-${var.env}-ecs-task-${var.tasks[count.index].name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  dynamic "inline_policy" {
    for_each = var.tasks[count.index].policies
    content {
      name   = "${var.project}-${var.env}-${var.tasks[count.index].name}-${inline_policy.value["name"]}"
      policy = inline_policy.value["policy"]
    }
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = "IAM role for the service ${var.tasks[count.index].name} in the ECS cluster"
  }
}

resource "aws_ecs_task_definition" "main" {
  count                    = length(var.tasks)
  family                   = "${var.project}-${var.env}-${var.tasks[count.index].name}"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task[count.index].arn
  network_mode             = "awsvpc"
  cpu                      = var.tasks[count.index].cpu
  memory                   = var.tasks[count.index].memory
  container_definitions = jsonencode([
    {
      name        = "${var.project}-${var.env}-${var.tasks[count.index].name}"
      image       = aws_ecr_repository.main[count.index].repository_url
      environment = var.tasks[count.index].env_variables
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.main[count.index].id
          awslogs-region        = var.region
          awslogs-stream-prefix = "cluster"
        }
      }
    }
  ])

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.tasks[count.index].description
  }
}

resource "aws_ecs_service" "main" {
  count                = length(var.tasks)
  name                 = "${var.project}-${var.env}-${var.tasks[count.index].name}"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.main[count.index].arn
  launch_type          = "FARGATE"
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnet_ids
    assign_public_ip = false
    security_groups  = var.tasks[count.index].security_groups
  }

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.tasks[count.index].description
  }
}
