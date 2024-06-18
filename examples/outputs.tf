output "s3_bucket_name" {
  value       = module.directus.s3_bucket_name
  description = "The name of the S3 bucket"
}

output "s3_bucket_arn" {
  value       = module.directus.s3_bucket_arn
  description = "The ARN of the S3 bucket"
}

output "load_balancer_dns_name" {
  value       = module.directus.load_balancer_dns_name
  description = "The DNS name of the load balancer"
}
