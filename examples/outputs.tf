output "s3_bucket_name" {
  value = module.directus.s3_bucket_name
}

output "s3_bucket_arn" {
  value = module.directus.s3_bucket_arn
}

output "load_balancer_dns_name" {
  value = module.directus.load_balancer_dns_name
}
