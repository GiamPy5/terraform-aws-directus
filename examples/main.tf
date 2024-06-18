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
# RDS Module
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

  rds_database_name                         = module.rds.db_instance_name
  rds_database_host                         = module.rds.db_instance_address
  rds_database_port                         = module.rds.db_instance_port
  rds_database_engine                       = module.rds.db_instance_engine
  rds_database_username                     = module.rds.db_instance_username
  rds_database_password_secrets_manager_arn = module.rds.db_instance_master_user_secret_arn

  create_s3_bucket = true # If you do not create an S3 bucket, you will need to provide an existing S3 bucket name
  s3_bucket_name   = "terraform-aws-directus-${local.region}"

  healthcheck_path = "/server/ping"
  image_tag        = "latest" # It's HIGHLY RECOMMENDED to specify an image tag instead of relying on "latest" as it could trigger unwanted updates.

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

  manage_master_user_password = true
}
