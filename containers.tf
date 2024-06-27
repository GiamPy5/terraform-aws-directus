locals {
  directus_container = {
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
      command     = ["CMD-SHELL", "wget -qO- http://localhost:${local.directus_port}${local.healthcheck_path} | grep -q 'ok' || exit 1"]
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

  xray_daemon_container = {
    name       = "xray-daemon"
    image      = "public.ecr.aws/xray/aws-xray-daemon:3.x"
    cpu        = 32
    memory     = 256
    entryPoint = ["/xray", "-b", "0.0.0.0:2000", "-o"]
    essential  = true
    healthCheck = {
      command  = ["CMD", "/xray", "--version", "||", "exit 1"]
      interval = 5
      timeout  = 2
      retries  = 1
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = var.create_cloudwatch_logs_group ? "true" : "false"
        "awslogs-group"         = "/aws/ecs/${var.application_name}-xray-daemon"
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.cloudwatch_logs_stream_prefix
      }
    }
    portMappings = [
      {
        containerPort = 2000
        protocol      = "udp"
      }
    ]
  }
}
