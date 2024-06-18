data "aws_s3_bucket" "directus" {
  count = var.create_s3_bucket == false ? 1 : 0

  bucket = var.s3_bucket_name
}

resource "aws_iam_role" "ecs_service_role" {
  name = "${var.application_name}-ecs-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_service_role_ecs_task_execution" {
  role       = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.application_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

data "aws_iam_policy_document" "cloudwatch_policy" {
  statement {
    sid = "CreateCloudWatchLogsGroup"

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name   = "${var.application_name}-cloudwatch-policy"
  path   = "/${var.application_name}/"
  policy = data.aws_iam_policy_document.cloudwatch_policy.json
}

resource "aws_iam_user" "directus" {
  name = "${var.application_name}-service-user"
  path = "/${var.application_name}/"
}

resource "aws_iam_access_key" "directus" {
  user = aws_iam_user.directus.name
}

resource "aws_iam_user_policy" "lb_ro" {
  name   = "${var.application_name}-s3-policy"
  user   = aws_iam_user.directus.name
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    sid = "CrudAccessInS3Bucket"

    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:Delete*",
      "s3:List*"
    ]

    resources = [
      local.s3_bucket_arn,
      "${local.s3_bucket_arn}/*"
    ]
  }
}
