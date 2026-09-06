variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for the dev environment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the DEV VPC"
  type        = string
}

variable "vpc_name" {
  description = "Name of the DEV VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the DEV subnet"
  type        = string
}

variable "subnet_name" {
  description = "Name of the DEV subnet"
  type        = string
}

variable "route_table_name" {
  description = "Name of the DEV route table"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the DEV EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the DEV EC2 instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the DEV EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Name of the EC2 key pair for the DEV environment"
  type        = string
}
