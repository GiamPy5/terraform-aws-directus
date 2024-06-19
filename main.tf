locals {
  cluster_name = "${var.application_name}-ecs-clstr"
  service_name = "directus"

  admin_password = var.admin_password == "" ? random_password.directus_admin_password[0].result : var.admin_password

  truncated_application_name = substr(var.application_name, 0, 20)

  s3_bucket_arn = var.create_s3_bucket ? aws_s3_bucket.directus[0].arn : data.aws_s3_bucket.directus[0].arn
  s3_bucket_id  = var.create_s3_bucket ? aws_s3_bucket.directus[0].id : data.aws_s3_bucket.directus[0].id

  s3_bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${local.truncated_application_name}-${local.service_name}-bucket-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  directus_port = 8055

  public_url = var.public_url != "" ? var.public_url : "http://${aws_lb.directus.dns_name}"

  is_https_enabled = strcontains(var.public_url, "https") ? true : false

  environment_vars = merge(
    var.additional_configuration,
    {
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
      EXTENSIONS_LOCATION         = "s3"
      PUBLIC_URL                  = local.public_url
    },
    var.redis_host != "" ? {
      CACHE_STORE           = "redis"
      RATE_LIMITER_STORE    = "redis"
      REDIS_HOST            = var.redis_host
      REDIS_PORT            = var.redis_port
      REDIS_USERNAME        = var.redis_username
      SYNCHRONIZATION_STORE = "redis"
      REDIS_PASSWORD        = "" # Secure transit not supported yet
    } : {},
    var.enable_ses_emails_sending ? {
      EMAIL_TRANSPORT  = "ses"
      EMAIL_SES_REGION = data.aws_region.current.name
    } : {}
  )

  container_definitions = [
    {
      name      = local.service_name
      image     = "directus/directus:${var.image_tag}"
      cpu       = var.cpu
      memory    = var.memory
      essential = true
      secrets = concat([
        { name : "SECRET", valueFrom : aws_secretsmanager_secret_version.directus_secret_version.arn },
        { name : "ADMIN_PASSWORD", valueFrom : aws_secretsmanager_secret_version.directus_admin_password_version.arn },
        { name : "DB_PASSWORD", valueFrom : "${var.rds_database_password_secrets_manager_arn}:password::" },
        { name : "STORAGE_S3_KEY", valueFrom : "${aws_secretsmanager_secret_version.directus_serviceuser_secret_version.arn}:access_key_id::" },
        { name : "STORAGE_S3_SECRET", valueFrom : "${aws_secretsmanager_secret_version.directus_serviceuser_secret_version.arn}:access_key_secret::" }
        ],
        var.enable_ses_emails_sending ? [
          { name : "EMAIL_SES_CREDENTIALS__ACCESS_KEY_ID", valueFrom : "${aws_secretsmanager_secret_version.directus_serviceuser_secret_version.arn}:access_key_id::" },
          { name : "EMAIL_SES_CREDENTIALS__SECRET_ACCESS_KEY", valueFrom : "${aws_secretsmanager_secret_version.directus_serviceuser_secret_version.arn}:access_key_secret::" }
      ] : [])
      environment = [for key, value in local.environment_vars : {
        name  = key
        value = value
      }]
      linuxParameters = {
        initProcessEnabled = true
      }
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
        command     = ["CMD-SHELL", "wget -qO- http://localhost:${local.directus_port}${var.healthcheck_path} | grep -q 'ok' || exit 1"]
        interval    = 60
        timeout     = 10
        retries     = 10
        startPeriod = 60
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

resource "aws_s3_bucket" "directus_lb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = "${local.truncated_application_name}-lb-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = var.tags
}

resource "random_password" "directus_secret" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "directus_admin_password" {
  count            = var.admin_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "directus_serviceuser_secret" {
  name_prefix = "${var.application_name}-${local.service_name}-serviceuser-secret"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus_serviceuser_secret_version" {
  secret_id = aws_secretsmanager_secret.directus_serviceuser_secret.id
  secret_string = jsonencode({
    access_key_id     = aws_iam_access_key.directus.id,
    access_key_secret = aws_iam_access_key.directus.secret
  })
}

resource "aws_secretsmanager_secret" "directus_secret" {
  name_prefix = "${var.application_name}-${local.service_name}-secret"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus_secret_version" {
  secret_id     = aws_secretsmanager_secret.directus_secret.id
  secret_string = random_password.directus_secret.result
}

resource "aws_secretsmanager_secret" "directus_admin_password" {
  name_prefix = "${var.application_name}-${local.service_name}-admin-password"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "directus_admin_password_version" {
  secret_id     = aws_secretsmanager_secret.directus_admin_password.id
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
    "awslogs" : aws_iam_policy.cloudwatch_logs_policy.arn
  }

  task_exec_secret_arns = [
    aws_secretsmanager_secret.directus_secret.arn,
    aws_secretsmanager_secret.directus_admin_password.arn,
    aws_secretsmanager_secret.directus_serviceuser_secret.arn,
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
        base   = 1
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

resource "aws_security_group" "ecs_sg" {
  name_prefix = "${local.truncated_application_name}-ecs-sg"
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

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_security_group" "lb_sg" {
  name_prefix = "${local.truncated_application_name}-lb-sg"
  description = "Allow inbound traffic on port ${local.is_https_enabled ? 443 : 80}"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = local.is_https_enabled ? 443 : 80
    to_port     = local.is_https_enabled ? 443 : 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}



resource "aws_lb" "directus" {
  name               = "${local.truncated_application_name}-${local.service_name}-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.lb_sg.id]

  enable_deletion_protection = false

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.directus_lb_logs[0].id
      prefix  = "alb-access-logs"
      enabled = true
    }
  }

  tags = var.tags
}

resource "aws_lb_target_group" "directus_lb_target_group" {
  name_prefix = "drctus"
  target_type = "ip"
  port        = local.is_https_enabled ? 443 : 80
  protocol    = local.is_https_enabled ? "HTTPS" : "HTTP"
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

resource "aws_lb_listener" "directus_lb_listener" {
  load_balancer_arn = aws_lb.directus.arn
  port              = local.is_https_enabled ? 443 : 80
  protocol          = local.is_https_enabled ? "HTTPS" : "HTTP"
  ssl_policy        = local.is_https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : ""
  certificate_arn   = local.is_https_enabled ? var.ssl_certificate_arn : ""

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.directus_lb_target_group.arn
  }

  tags = var.tags
}

resource "aws_ecs_service" "directus" {
  name            = local.service_name
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.directus.arn
  launch_type     = "FARGATE"

  desired_count = 1

  health_check_grace_period_seconds = 60
  enable_execute_command            = var.ecs_service_enable_execute_command

  force_new_deployment = var.force_new_ecs_deployment_on_apply

  load_balancer {
    target_group_arn = aws_lb_target_group.directus_lb_target_group.arn
    container_name   = local.service_name
    container_port   = local.directus_port
  }

  network_configuration {
    assign_public_ip = true
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "directus" {
  family = "${local.truncated_application_name}-${local.service_name}"

  network_mode = "awsvpc"

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = module.ecs.task_exec_iam_role_arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode(local.container_definitions)

  tags = var.tags
}

resource "aws_appautoscaling_target" "autoscaling_target" {
  count              = var.autoscaling.enable ? 1 : 0
  max_capacity       = var.autoscaling.max_capacity
  min_capacity       = var.autoscaling.min_capacity
  resource_id        = "service/${local.cluster_name}/${local.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "autoscaling_policy_memory" {
  count              = var.autoscaling.enable ? 1 : 0
  name               = "${local.cluster_name}-memory-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = var.autoscaling.memory_threshold
  }
}

resource "aws_appautoscaling_policy" "autoscaling_policy_cpu" {
  count              = var.autoscaling.enable ? 1 : 0
  name               = "${local.cluster_name}-cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autoscaling_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.autoscaling_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.autoscaling_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = var.autoscaling.cpu_threshold
  }
}
