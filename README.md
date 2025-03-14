# Terraform AWS Directus Module 🚀

This Terraform module simplifies the deployment of [Directus](https://directus.io/) on an AWS Fargate ECS cluster.

## 🌟 Features

- **Seamless Deployment** of Directus on AWS Fargate ECS
- **Automatic Scaling** and Load Balancing
- **High Availability** and Fault Tolerance
- **Customizable Configuration** Options
- **S3 Integration** for Static Assets

## 🚀 Quick Start

Deploy Directus quickly and easily by including this module in your Terraform configuration:

```hcl
module "directus" {
  source  = "GiamPy5/directus/aws"

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

  rds_database_name                         = "database_name"
  rds_database_host                         = "database_host"
  rds_database_port                         = "database_port"
  rds_database_engine                       = "database_engine"
  rds_database_username                     = "database_username"
  rds_database_password_secrets_manager_arn = "database_user_password_secrets_manager_arn"

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
  } # Change these tags to your preferred tags
}
```

For a complete example, including all dependencies like database inputs, check out the [examples](https://github.com/GiamPy5/terraform-aws-directus/tree/main/examples) section.

## 📋 Prerequisites

Before using this module, ensure you have the following:

- An **AWS account** 🛠️
- **Terraform installed** on your machine 🌐
- Basic knowledge of **AWS services** and **Terraform** 📚

## 📚 Module Documentation

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.30 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.30 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecs"></a> [ecs](#module\_ecs) | terraform-aws-modules/ecs/aws | 5.11.2 |
| <a name="module_s3_bucket_for_logs"></a> [s3\_bucket\_for\_logs](#module\_s3\_bucket\_for\_logs) | terraform-aws-modules/s3-bucket/aws | 4.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.autoscaling_policy_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.autoscaling_policy_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.autoscaling_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_ecs_service.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_access_key.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_group.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group) | resource |
| [aws_iam_group_membership.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_membership) | resource |
| [aws_iam_group_policy.s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy) | resource |
| [aws_iam_policy.cloudwatch_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ecs_ebs_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecs_ebs_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_service_role_ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_lb.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.directus_lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.directus_lb_target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_s3_bucket.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.directus_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.cognito_client_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.directus_admin_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.directus_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.directus_serviceuser_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.cognito_client_secret_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.directus_admin_password_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.directus_secret_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.directus_serviceuser_secret_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.ecs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.lb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_password.directus_admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.directus_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cognito_user_pool_client.client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cognito_user_pool_client) | data source |
| [aws_iam_policy_document.cloudwatch_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms_access_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_s3_bucket.directus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_configuration"></a> [additional\_configuration](#input\_additional\_configuration) | Additional configuration to apply to the Directus container | `map(string)` | `{}` | no |
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | The email address of the admin user | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The password of the admin user (if empty, it will be generated automatically) | `string` | `""` | no |
| <a name="input_application_name"></a> [application\_name](#input\_application\_name) | The name of the application | `string` | n/a | yes |
| <a name="input_autoscaling"></a> [autoscaling](#input\_autoscaling) | Autoscaling Configuration | <pre>object({<br>    enable           = bool<br>    memory_threshold = number<br>    cpu_threshold    = number<br>    min_capacity     = number<br>    max_capacity     = number<br>  })</pre> | <pre>{<br>  "cpu_threshold": 60,<br>  "enable": false,<br>  "max_capacity": 3,<br>  "memory_threshold": 80,<br>  "min_capacity": 1<br>}</pre> | no |
| <a name="input_cloudwatch_logs_stream_prefix"></a> [cloudwatch\_logs\_stream\_prefix](#input\_cloudwatch\_logs\_stream\_prefix) | The prefix of the CloudWatch Logs stream | `string` | `"directus"` | no |
| <a name="input_cognito_allow_public_registration"></a> [cognito\_allow\_public\_registration](#input\_cognito\_allow\_public\_registration) | Whether to allow public registration in Directus through Cognito External Users | `bool` | `false` | no |
| <a name="input_cognito_identifier_key"></a> [cognito\_identifier\_key](#input\_cognito\_identifier\_key) | The key of the Cognito identifier | `string` | `"email"` | no |
| <a name="input_cognito_scopes"></a> [cognito\_scopes](#input\_cognito\_scopes) | The Cognito scopes | `list(string)` | <pre>[<br>  "email",<br>  "openid",<br>  "profile"<br>]</pre> | no |
| <a name="input_cognito_user_pool_client_id"></a> [cognito\_user\_pool\_client\_id](#input\_cognito\_user\_pool\_client\_id) | The ID of the Cognito user pool client | `string` | `""` | no |
| <a name="input_cognito_user_pool_id"></a> [cognito\_user\_pool\_id](#input\_cognito\_user\_pool\_id) | The ID of the Cognito user pool | `string` | `""` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | The number of CPU units to reserve for the Directus service | `number` | `2048` | no |
| <a name="input_create_cloudwatch_logs_group"></a> [create\_cloudwatch\_logs\_group](#input\_create\_cloudwatch\_logs\_group) | Whether to create a CloudWatch Logs group | `bool` | `false` | no |
| <a name="input_create_s3_bucket"></a> [create\_s3\_bucket](#input\_create\_s3\_bucket) | Whether to create an S3 bucket | `bool` | `false` | no |
| <a name="input_ecs_security_group_ids"></a> [ecs\_security\_group\_ids](#input\_ecs\_security\_group\_ids) | The IDs of the security groups to attach to the ECS service | `list(string)` | `[]` | no |
| <a name="input_ecs_service_enable_execute_command"></a> [ecs\_service\_enable\_execute\_command](#input\_ecs\_service\_enable\_execute\_command) | Whether to enable ECS service execute command | `bool` | `false` | no |
| <a name="input_enable_alb_access_logs"></a> [enable\_alb\_access\_logs](#input\_enable\_alb\_access\_logs) | Whether to enable access logs of the Load Balancer | `bool` | `false` | no |
| <a name="input_enable_cognito_authentication"></a> [enable\_cognito\_authentication](#input\_enable\_cognito\_authentication) | Whether to enable Cognito authentication | `bool` | `false` | no |
| <a name="input_enable_ecs_volume"></a> [enable\_ecs\_volume](#input\_enable\_ecs\_volume) | Whether to enable ECS volume | `bool` | `false` | no |
| <a name="input_enable_kms_encryption"></a> [enable\_kms\_encryption](#input\_enable\_kms\_encryption) | Whether to enable KMS encryption | `bool` | `false` | no |
| <a name="input_enable_s3_bucket_versioning"></a> [enable\_s3\_bucket\_versioning](#input\_enable\_s3\_bucket\_versioning) | Whether to enable S3 bucket versioning | `bool` | `true` | no |
| <a name="input_enable_ses_emails_sending"></a> [enable\_ses\_emails\_sending](#input\_enable\_ses\_emails\_sending) | Whether to enable sending emails using SES | `bool` | `false` | no |
| <a name="input_force_new_ecs_deployment_on_apply"></a> [force\_new\_ecs\_deployment\_on\_apply](#input\_force\_new\_ecs\_deployment\_on\_apply) | Whether to force a new deployment of the ECS service on apply | `bool` | `false` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | The tag of the Docker image | `string` | `"latest"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The ID of the KMS key | `string` | `""` | no |
| <a name="input_load_balancer_allowed_cidr_blocks"></a> [load\_balancer\_allowed\_cidr\_blocks](#input\_load\_balancer\_allowed\_cidr\_blocks) | The CIDR blocks allowed to access the Load Balancer | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_load_balancer_prefix_list_ids"></a> [load\_balancer\_prefix\_list\_ids](#input\_load\_balancer\_prefix\_list\_ids) | The prefix list IDs allowed to access the Load Balancer | `list(string)` | `[]` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | The amount of memory to reserve for the Directus service | `number` | `4096` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | The IDs of the private subnets used by the ECS service to run tasks | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | The IDs of the public subnets used by the Load Balancer to serve traffic | `list(string)` | n/a | yes |
| <a name="input_public_url"></a> [public\_url](#input\_public\_url) | The public URL of the Directus service | `string` | `""` | no |
| <a name="input_rds_database_engine"></a> [rds\_database\_engine](#input\_rds\_database\_engine) | The engine of the RDS database | `string` | n/a | yes |
| <a name="input_rds_database_host"></a> [rds\_database\_host](#input\_rds\_database\_host) | The host of the RDS database | `string` | n/a | yes |
| <a name="input_rds_database_name"></a> [rds\_database\_name](#input\_rds\_database\_name) | The Name of the RDS database | `string` | n/a | yes |
| <a name="input_rds_database_password_secrets_manager_arn"></a> [rds\_database\_password\_secrets\_manager\_arn](#input\_rds\_database\_password\_secrets\_manager\_arn) | The ARN of the Secrets Manager secret containing the RDS database password | `string` | n/a | yes |
| <a name="input_rds_database_port"></a> [rds\_database\_port](#input\_rds\_database\_port) | The port of the RDS database | `number` | n/a | yes |
| <a name="input_rds_database_username"></a> [rds\_database\_username](#input\_rds\_database\_username) | The username of the RDS database user | `string` | n/a | yes |
| <a name="input_redis_host"></a> [redis\_host](#input\_redis\_host) | The host of the Redis server | `string` | `""` | no |
| <a name="input_redis_port"></a> [redis\_port](#input\_redis\_port) | The port of the Redis server | `number` | `6379` | no |
| <a name="input_redis_username"></a> [redis\_username](#input\_redis\_username) | The username of the Redis server | `string` | `"default"` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | The name of the S3 bucket | `string` | `""` | no |
| <a name="input_s3_bucket_versioning_configuration"></a> [s3\_bucket\_versioning\_configuration](#input\_s3\_bucket\_versioning\_configuration) | S3 bucket versioning configuration | <pre>object({<br>    mfa_delete = string<br>  })</pre> | <pre>{<br>  "mfa_delete": "Disabled"<br>}</pre> | no |
| <a name="input_ssl_certificate_arn"></a> [ssl\_certificate\_arn](#input\_ssl\_certificate\_arn) | The ARN of the SSL certificate | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | The tags to apply to the resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_load_balancer_dns_name"></a> [load\_balancer\_dns\_name](#output\_load\_balancer\_dns\_name) | The DNS name of the load balancer |
| <a name="output_load_balancer_listener_arn"></a> [load\_balancer\_listener\_arn](#output\_load\_balancer\_listener\_arn) | The ARN of the load balancer listener |
| <a name="output_load_balancer_target_group_arn"></a> [load\_balancer\_target\_group\_arn](#output\_load\_balancer\_target\_group\_arn) | The ARN of the load balancer target group |
| <a name="output_public_url"></a> [public\_url](#output\_public\_url) | The public URL of the Directus service |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | The name of the S3 bucket |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## 🤝 Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or submit a pull request on the [GitHub repository](https://github.com/GiamPy5/terraform-aws-directus).

## 📄 License

This module is open source and available under the [MIT License](https://opensource.org/licenses/MIT).
