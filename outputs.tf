output "s3_bucket_name" {
  value       = local.s3_bucket_name
  description = "The name of the S3 bucket"
}

output "s3_bucket_arn" {
  value       = local.s3_bucket_arn
  description = "The ARN of the S3 bucket"
}

output "load_balancer_dns_name" {
  value       = aws_lb.directus.dns_name
  description = "The DNS name of the load balancer"
}
