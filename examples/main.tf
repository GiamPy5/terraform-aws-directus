provider "aws" {
  region = local.region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

locals {
  name = "terraform-aws-directus"

  domain_name             = "example.com"
  application_domain_name = "directus.${local.domain_name}"

  region = "eu-central-1"

  super_secret_token = "super_secret_token"

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

  public_url = "https://${local.application_domain_name}"

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

  ssl_certificate_arn = aws_acm_certificate.cert.arn

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

  image_tag = "10.12"

  # This disables the default behavior of the Load Balancer, it's heavily recommended when you want to use CloudFront.
  # See: https://logan-cox.com/posts/secure_alb/
  load_balancer_allowed_cidr_blocks = []

  # This allows connections only from CloudFront
  load_balancer_prefix_list_ids = [
    data.aws_ec2_managed_prefix_list.cloudfront_prefix_list.id
  ]

  enable_alb_access_logs = true

  enable_s3_bucket_versioning = true

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

# Network
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

# RDS Database
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

# Redis
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

# Application Domain
data "aws_route53_zone" "hosted_zone" {
  name = local.domain_name
}

resource "aws_route53_record" "loadbalancer_cname" {
  name    = "lb.${local.application_domain_name}"
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "CNAME"
  ttl     = 60
  records = [module.directus.load_balancer_dns_name]
}

resource "aws_route53_record" "websiteurl" {
  name    = local.application_domain_name
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cloudfront_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

# Domain Certificate
resource "aws_acm_certificate" "cert" {
  domain_name               = local.application_domain_name
  subject_alternative_names = ["*.${local.application_domain_name}"]
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for d in aws_acm_certificate.cert.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.hosted_zone.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# CloudFront Certificate

resource "aws_acm_certificate" "cert_cloudfront" {
  provider = aws.us-east-1

  domain_name               = local.application_domain_name
  subject_alternative_names = ["*.${local.application_domain_name}"]
  validation_method         = "DNS"
  tags                      = local.tags
}

resource "aws_route53_record" "cert_validation_cloudfront" {
  for_each = {
    for d in aws_acm_certificate.cert.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      record = d.resource_record_value
      type   = d.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.hosted_zone.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation_cloudfront" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.cert_cloudfront.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation_cloudfront : r.fqdn]
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  enabled = true
  aliases = [local.application_domain_name]
  origin {
    domain_name = "lb.${local.application_domain_name}"
    origin_id   = "lb.${local.application_domain_name}"
    custom_header {
      name  = "X-CloudFront-Token"
      value = local.super_secret_token
    }
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  default_root_object = "server/info"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "lb.${local.application_domain_name}"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      headers      = []
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IT", "PL"]
    }
  }
  tags = local.tags
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert_cloudfront.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront_prefix_list" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_lb_listener_rule" "additional_listener" {
  listener_arn = module.directus.load_balancer_listener_arn

  action {
    type             = "forward"
    target_group_arn = module.directus.load_balancer_target_group_arn
  }

  condition {
    host_header {
      values = [
        aws_route53_record.websiteurl.name
      ]
    }
  }

  condition {
    http_header {
      http_header_name = "X-CloudFront-Token"
      values           = [local.super_secret_token]
    }
  }
}
