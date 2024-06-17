locals {
  cluster_name = "${var.application_name}-ecs-clstr"

  admin_password = var.admin_password == "" ? random_password.directus-admin-password[0].result : var.admin_password

  truncated_application_name = substr(var.application_name, 0, 20)

  s3_bucket_arn = var.create_s3_bucket ? aws_s3_bucket.directus[0].arn : data.aws_s3_bucket.directus[0].arn
  s3_bucket_id  = var.create_s3_bucket ? aws_s3_bucket.directus[0].id : data.aws_s3_bucket.directus[0].id

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.truncated_application_name}-directus-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  directus_port = 8055

  environment_vars = merge(var.additional_configuration, {
    ADMIN_EMAIL                 = var.admin_email
    DB_CLIENT                   = var.rds_database_engine
    DB_HOST                     = var.rds_database_host
    DB_PORT                     = tostring(var.rds_database_port)
    DB_DATABASE                 = var.rds_database_name
    DB_USER                     = var.rds_database_username
    DB_SSL__REJECT_UNAUTHORIZED = "false"
    WEBSOCKETS_ENABLED          = "true"
    STORAGE_LOCATIONS           = "s3"
    STORAGE_S3_DRIVER           = "s3"
    STORAGE_S3_BUCKET           = local.s3_bucket_id
    STORAGE_S3_REGION           = data.aws_region.current.name
    PUBLIC_URL                  = "http://${aws_lb.directus.dns_name}"
  })

  container_definitions = [
    {
      name      = "directus"
      image     = "directus/directus:${var.image_tag}"
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      secrets = [
        { name : "SECRET", valueFrom : aws_secretsmanager_secret_version.directus-secret-version.arn },
        { name : "ADMIN_PASSWORD", valueFrom : aws_secretsmanager_secret_version.directus-admin-password-version.arn },
        { name : "DB_PASSWORD", valueFrom : "${var.rds_database_password_secrets_manager_arn}:password::" },
        { name : "STORAGE_S3_KEY", valueFrom : "${aws_secretsmanager_secret_version.directus-serviceuser-secret-version.arn}:access_key_id::" },
        { name : "STORAGE_S3_SECRET", valueFrom : "${aws_secretsmanager_secret_version.directus-serviceuser-secret-version.arn}:access_key_secret::" }
      ]
      environment = [for key, value in local.environment_vars : {
        name  = key
        value = value
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = var.create_cloudwatch_logs_group ? "true" : "false"
          "awslogs-group"         = "/aws/ecs/${var.application_name}"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.cloudwatch_logs_stream_prefix
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:${local.directus_port}${var.healthcheck_path} | grep -q 'pong' || exit 1"]
        interval    = 60
        timeout     = 10
        retries     = 5
        startPeriod = 30
      }
      portMappings = [
        {
          containerPort = local.directus_port
          hostPort      = local.directus_port
          protocol      = "tcp"
        }
      ]
    }
  ]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "directus" {
  count = var.create_s3_bucket ? 1 : 0

  bucket = local.s3_bucket_name

  tags = var.tags
}

resource "random_password" "directus-secret" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "directus-admin-password" {
  count            = var.admin_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "directus-serviceuser-secret" {
  name_prefix = "${var.application_name}-directus-serviceuser-secret"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus-serviceuser-secret-version" {
  secret_id = aws_secretsmanager_secret.directus-serviceuser-secret.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.directus.id,
    access_key_secret = aws_iam_access_key.directus.secret
  })
}

resource "aws_secretsmanager_secret" "directus-secret" {
  name_prefix = "${var.application_name}-directus-secret"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus-secret-version" {
  secret_id     = aws_secretsmanager_secret.directus-secret.id
  secret_string = random_password.directus-secret.result
}

resource "aws_secretsmanager_secret" "directus-admin-password" {
  name_prefix = "${var.application_name}-directus-admin-password"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus-admin-password-version" {
  secret_id     = aws_secretsmanager_secret.directus-admin-password.id
  secret_string = local.admin_password
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.11.2"

  cluster_name = local.cluster_name

  create_task_exec_policy            = true
  create_task_exec_iam_role          = true
  task_exec_iam_role_use_name_prefix = false

  task_exec_iam_role_name = "${local.cluster_name}-task-exec-role"
  task_exec_iam_role_path = "/ecs/${local.cluster_name}/"
  task_exec_iam_role_policies = {
    "awslogs" : aws_iam_policy.cloudwatch-logs-policy.arn
  }

  task_exec_secret_arns = [
    aws_secretsmanager_secret.directus-secret.arn,
    aws_secretsmanager_secret.directus-admin-password.arn,
    aws_secretsmanager_secret.directus-serviceuser-secret.arn,
    var.rds_database_password_secrets_manager_arn
  ]

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.application_name}"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  tags = var.tags
}

resource "aws_security_group" "ecs-sg" {
  name        = "${local.truncated_application_name}-ecs-sg"
  description = "Allow inbound traffic on port 8055"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 8055
    to_port     = 8055
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "lb_sg" {
  name        = "${local.truncated_application_name}-lb-sg"
  description = "Allow inbound traffic on port 80"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   description = "Allow HTTPS traffic"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_lb" "directus" {
  name               = "${local.truncated_application_name}-directus-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.lb_sg.id]

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = var.tags
}

resource "aws_lb_target_group" "directus-lb-target-group-http" {
  name_prefix = "dcts80"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.healthcheck_path
    protocol            = "HTTP"
    matcher             = "200,304"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# resource "aws_lb_target_group" "directus-lb-target-group-https" {
#   name        = "${local.truncated_application_name}-https-tg"
#   target_type = "ip"
#   port        = 443
#   protocol    = "HTTPS"
#   vpc_id      = var.vpc_id
# }

resource "aws_lb_listener" "directus-lb-listener-http" {
  load_balancer_arn = aws_lb.directus.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.directus-lb-target-group-http.arn
  }

  tags = var.tags
}

# resource "aws_lb_listener" "directus-lb-listener-https" {
#   load_balancer_arn = aws_lb.directus.arn
#   port              = "443"
#   protocol          = "HTTPS"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.directus-lb-target-group-https.arn
#   }
# }

resource "aws_ecs_service" "directus" {
  name            = "directus"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.directus.arn
  launch_type     = "FARGATE"

  desired_count = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.directus-lb-target-group-http.arn
    container_name   = "directus"
    container_port   = local.directus_port
  }

  # load_balancer {
  #   target_group_arn = aws_lb_target_group.directus-lb-target-group-https.arn
  #   container_name   = "directus"
  #   container_port   = local.directus_port
  # }

  network_configuration {
    assign_public_ip = true
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs-sg.id]
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "directus" {
  family = "${local.truncated_application_name}-directus"

  network_mode = "awsvpc"

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = module.ecs.task_exec_iam_role_arn
  task_role_arn      = aws_iam_role.ecs-task-role.arn

  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode(local.container_definitions)

  tags = var.tags
}

