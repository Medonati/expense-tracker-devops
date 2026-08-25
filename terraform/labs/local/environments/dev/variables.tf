variable "filename" {
  description = "Name of the file Terraform should manage in the dev environment"
  type        = string
}

variable "content" {
  description = "Content of the file managed by Terraform"
  type        = string
}
