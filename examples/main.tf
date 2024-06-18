provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
  name = "terraform-aws-directus"

  region = "eu-central-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/GiamPy5/terraform-aws-directus"
  }
}

################################################################################
# Directus Module
################################################################################

module "directus" {
  source = "./.."

  application_name = local.name                # Change this to your application name
  admin_email      = "fake-email@email.com"    # Change this to your email address
  vpc_id           = module.vpc.vpc_id         # Change this to your VPC ID
  subnet_ids       = module.vpc.public_subnets # Change this to your subnet IDs

  create_cloudwatch_logs_group  = true
  cloudwatch_logs_stream_prefix = "directus"

  cpu    = 1024
  memory = 2048

  ecs_service_enable_execute_command = true # Allows you to connect via CLI to the ECS Task Container (just like `docker exec`). It's disabled by default.
  enable_ses_emails_sending          = true
  force_new_ecs_deployment_on_apply  = true

  # Add additional custom configuration here (https://docs.directus.io/self-hosted/config-options.html#configuration-options)
  additional_configuration = {
    "LOG_LEVEL" = "debug"
  }

  rds_database_name                         = module.rds.db_instance_name
  rds_database_host                         = module.rds.db_instance_address
  rds_database_port                         = module.rds.db_instance_port
  rds_database_engine                       = module.rds.db_instance_engine
  rds_database_username                     = module.rds.db_instance_username
  rds_database_password_secrets_manager_arn = module.rds.db_instance_master_user_secret_arn

  redis_host = module.elasticache.cluster_cache_nodes[0].address
  redis_port = module.elasticache.cluster_cache_nodes[0].port

  create_s3_bucket = true # If you do not create an S3 bucket, you will need to provide an existing S3 bucket name
  s3_bucket_name   = "terraform-aws-directus-${local.region}"

  healthcheck_path = "/server/health"
  image_tag        = "10.12"

  autoscaling = {
    enable           = true
    cpu_threshold    = 60
    memory_threshold = 80
    min_capacity     = 1
    max_capacity     = 2
  }

  tags = {
    Application = "Directus"
    Environment = "Test"
  } # Change these tags to your prefered tags
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.7.0"

  identifier = "directus"

  engine               = "mysql"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 5

  db_name  = "directus"
  username = "user"
  port     = "3306"

  vpc_security_group_ids = [module.security_group.security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group

  skip_final_snapshot         = true
  manage_master_user_password = true
}

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "1.2.0"

  cluster_id               = local.name
  create_cluster           = true
  create_replication_group = false

  engine_version = "7.1"
  node_type      = "cache.t4g.micro"

  maintenance_window = "sun:05:00-sun:09:00"
  apply_immediately  = true

  # Security Group
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_vpc = {
      # Default type is `ingress`
      # Default port is based on the default engine port
      description = "VPC traffic"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  # Subnet Group
  subnet_group_name        = local.name
  subnet_group_description = "${title(local.name)} subnet group"
  subnet_ids               = module.vpc.private_subnets

  # Parameter Group
  create_parameter_group      = true
  parameter_group_name        = local.name
  parameter_group_family      = "redis7"
  parameter_group_description = "${title(local.name)} parameter group"
  parameters = [
    {
      name  = "latency-tracking"
      value = "yes"
    }
  ]

  tags = local.tags
}
