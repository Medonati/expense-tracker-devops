output "bucket_name" {
  description = "Name of the S3 bucket created for the dev environment"
  value       = module.storage.bucket_name
}

output "vpc_cidr" {
  description = "CIDR block of the DEV VPC"
  value       = module.networking.vpc_cidr
}

output "subnet_id" {
  description = "ID of the DEV subnet"
  value       = module.networking.subnet_id
}

output "subnet_cidr" {
  description = "CIDR block of the DEV subnet"
  value       = module.networking.subnet_cidr
}

output "vpc_id" {
  description = "ID of the DEV VPC"
  value       = module.networking.vpc_id
}

output "ecr_repository_url" {
  description = "URL of the DEV ECR repository"
  value       = module.ecr.repository_url
}

output "instance_id" {
  description = "ID of the DEV EC2 instance"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the DEV EC2 instance"
  value       = module.compute.public_ip
}
