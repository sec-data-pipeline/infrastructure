resource "aws_ecr_repository" "main" {
  name                 = "${var.project}-${var.env}-${var.name}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Project     = var.project
    Environment = var.env
    Description = var.description
  }
}
