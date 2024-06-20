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

output "load_balancer_target_group_arn" {
  value       = aws_lb_target_group.directus_lb_target_group.arn
  description = "The ARN of the load balancer target group"
}

output "load_balancer_listener_arn" {
  value       = aws_lb_listener.directus_lb_listener.arn
  description = "The ARN of the load balancer listener"
}
