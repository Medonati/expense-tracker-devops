output "bucket_name" {
  description = "Name of the S3 bucket created for the dev environment"
  value       = module.storage.bucket_name
}
