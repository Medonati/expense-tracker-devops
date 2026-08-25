variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the dev environment"
  type        = string
}
