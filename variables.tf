variable "create_s3_bucket" {
  description = "Whether to create an S3 bucket"
  type        = bool
  default     = false
}

variable "public_url" {
  description = "The public URL of the Directus service"
  type        = string
  default     = ""
}

variable "load_balancer_allowed_cidr_blocks" {
  description = "The CIDR blocks allowed to access the Load Balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "load_balancer_prefix_list_ids" {
  description = "The prefix list IDs allowed to access the Load Balancer"
  type        = list(string)
  default     = []
}

variable "create_cloudwatch_logs_group" {
  description = "Whether to create a CloudWatch Logs group"
  type        = bool
  default     = false
}

variable "enable_alb_access_logs" {
  description = "Whether to enable access logs of the Load Balancer"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "The ARN of the SSL certificate"
  type        = string
  default     = ""
}

variable "enable_ses_emails_sending" {
  description = "Whether to enable sending emails using SES"
  type        = bool
  default     = false
}

variable "enable_s3_bucket_versioning" {
  description = "Whether to enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_bucket_versioning_configuration" {
  type = object({
    mfa_delete = string
  })
  description = "S3 bucket versioning configuration"
  default = {
    mfa_delete = "Disabled"
  }
}

variable "kms_key_id" {
  description = "The ID of the KMS key"
  type        = string
  default     = ""
}

variable "ecs_service_enable_execute_command" {
  description = "Whether to enable ECS service execute command"
  type        = bool
  default     = false
}

variable "autoscaling" {
  description = "Autoscaling Configuration"
  type = object({
    enable           = bool
    memory_threshold = number
    cpu_threshold    = number
    min_capacity     = number
    max_capacity     = number
  })
  default = {
    enable           = false
    memory_threshold = 80
    cpu_threshold    = 60
    min_capacity     = 1
    max_capacity     = 3
  }
}

variable "force_new_ecs_deployment_on_apply" {
  description = "Whether to force a new deployment of the ECS service on apply"
  type        = bool
  default     = false
}

variable "redis_host" {
  description = "The host of the Redis server"
  type        = string
  default     = ""
}

variable "redis_port" {
  description = "The port of the Redis server"
  type        = number
  default     = 6379
}

variable "redis_username" {
  description = "The username of the Redis server"
  type        = string
  default     = "default"
}

variable "cpu" {
  description = "The number of CPU units to reserve for the Directus service"
  type        = number
  default     = 2048
}

variable "memory" {
  description = "The amount of memory to reserve for the Directus service"
  type        = number
  default     = 4096
}

variable "cloudwatch_logs_stream_prefix" {
  description = "The prefix of the CloudWatch Logs stream"
  type        = string
  default     = "directus"
}

variable "additional_configuration" {
  description = "Additional configuration to apply to the Directus container"
  type        = map(string)
  default     = {}
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = ""
}

variable "rds_database_name" {
  description = "The Name of the RDS database"
  type        = string
}

variable "rds_database_engine" {
  description = "The engine of the RDS database"
  type        = string
}

variable "rds_database_host" {
  description = "The host of the RDS database"
  type        = string
}

variable "rds_database_port" {
  description = "The port of the RDS database"
  type        = number
}

variable "rds_database_username" {
  description = "The username of the RDS database user"
  type        = string
}

variable "rds_database_password_secrets_manager_arn" {
  description = "The ARN of the Secrets Manager secret containing the RDS database password"
  type        = string
}

variable "application_name" {
  description = "The name of the application"
  type        = string
}

variable "image_tag" {
  description = "The tag of the Docker image"
  type        = string
  default     = "latest"
}

variable "admin_email" {
  description = "The email address of the admin user"
  type        = string
}

variable "admin_password" {
  description = "The password of the admin user (if empty, it will be generated automatically)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the subnets"
  type        = list(string)
}

variable "tags" {
  description = "The tags to apply to the resources"
  type        = map(string)
  default     = {}
}
