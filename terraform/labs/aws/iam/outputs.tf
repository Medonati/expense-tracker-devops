output "terraform_role_arn" {
  description = "ARN of the Terraform execution role"
  value       = aws_iam_role.terraform_execution.arn
}

output "terraform_policy_arn" {
  description = "ARN of the Terraform execution policy"
  value       = aws_iam_policy.terraform_execution.arn
}
