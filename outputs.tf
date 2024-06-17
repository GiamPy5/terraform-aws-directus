output "s3_bucket_name" {
  value = local.s3_bucket_name
}

output "s3_bucket_arn" {
  value = local.s3_bucket_arn
}

output "load_balancer_dns_name" {
  value = aws_lb.directus.dns_name
}
