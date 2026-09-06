data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_execution" {
  statement {
    sid    = "S3BucketLifecycle"
    effect = "Allow"

    actions = [
      "s3:CreateBucket"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "S3InfrastructureBucketRead"
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::expense-tracker-dev-terraform-2026"
    ]
  }

  statement {
    sid    = "S3InfrastructureBucketLifecycle"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket"
    ]

    resources = [
      "arn:aws:s3:::expense-tracker-dev-terraform-2026"
    ]
  }

  statement {
    sid    = "TerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::terraform-devops-state-medon-2026/terraform-state-lab/dev/terraform.tfstate",
      "arn:aws:s3:::terraform-devops-state-medon-2026/terraform-state-lab/dev/terraform.tfstate.tflock"
    ]
  }

  statement {
    sid    = "VPCNetworkingManagement"
    effect = "Allow"

    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",

      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:ModifySubnetAttribute",

      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",

      "ec2:CreateRoute",
      "ec2:ReplaceRoute",
      "ec2:DeleteRoute",

      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",

      "ec2:CreateTags",
      "ec2:DeleteTags",

      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAvailabilityZones"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EC2ComputeManagement"
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:Describe*",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:ModifyNetworkInterfaceAttribute"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "EC2SecurityGroupManagement"
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DescribeSecurityGroups"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ECRRepositoryManagement"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:PutImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:ListImages",
      "ecr:ListTagsForResource",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "IAMRoleAndPolicyManagement"
    effect = "Allow"

    actions = [
      # Roles
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",

      # Managed policies
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicyVersion",

      # Instance profiles
      "iam:GetInstanceProfile",
      "iam:ListInstanceProfilesForRole"
    ]

    resources = ["*"]
  }

}

resource "aws_iam_policy" "terraform_execution" {
  name        = "terraform-dev-execution-policy"
  description = "Least-privilege permissions for Terraform DEV infrastructure management"

  policy = data.aws_iam_policy_document.terraform_execution.json
}

resource "aws_iam_role" "terraform_execution" {
  name = "terraform-dev-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_execution" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = aws_iam_policy.terraform_execution.arn
}
