variable "create_s3_bucket" {
  description = "Whether to create an S3 bucket"
  type        = bool
  default     = false
}

variable "create_cloudwatch_logs_group" {
  description = "Whether to create a CloudWatch Logs group"
  type        = bool
  default     = false
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

variable "healthcheck_path" {
  description = "The path of the healthcheck endpoint"
  type        = string
  default     = "/server/ping"
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
