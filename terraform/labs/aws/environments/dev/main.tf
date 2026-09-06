terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-devops-state-medon-2026"
    key          = "terraform-state-lab/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::748241639517:role/terraform-dev-execution-role"
  }
}

module "storage" {
  source = "../../modules/storage"

  bucket_name = var.bucket_name
}

module "networking" {
  source = "../../modules/networking"

  vpc_cidr         = var.vpc_cidr
  vpc_name         = var.vpc_name
  subnet_cidr      = var.subnet_cidr
  subnet_name      = var.subnet_name
  route_table_name = var.route_table_name
}

module "security" {
  source = "../../modules/security"

  vpc_id              = module.networking.vpc_id
  security_group_name = "expense-tracker-dev-sg"
}

module "compute" {

  source               = "../../modules/compute"
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  instance_name        = var.instance_name
  subnet_id            = module.networking.subnet_id
  security_group_ids   = [module.security.security_group_id]
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  key_name             = var.key_name
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = "expense-tracker-dev-backend"
}
