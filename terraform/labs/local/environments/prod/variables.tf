variable "filename" {
  description = "Name of the file Terraform should manage in the prod environment"
  type        = string
}

variable "content" {
  description = "Content of the file managed by Terraform"
  type        = string
}
