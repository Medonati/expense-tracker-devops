terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }

  backend "s3" {
    bucket       = "terraform-devops-state-medon-2026"
    key          = "terraform-state-lab/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "local" {}

module "file" {
  source = "../../modules/file"

  filename = var.filename
  content  = var.content
}
