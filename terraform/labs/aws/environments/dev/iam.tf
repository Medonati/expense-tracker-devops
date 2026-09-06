resource "aws_iam_role" "ec2" {
  name = "expense-tracker-dev-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_ecr_pull" {
  name        = "expense-tracker-dev-ec2-ecr-pull"
  description = "Allow the DEV EC2 instance to pull container images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]

        Resource = "arn:aws:ecr:${var.aws_region}:748241639517:repository/expense-tracker-dev-backend"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_pull" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_ecr_pull.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "expense-tracker-dev-ec2-profile"
  role = aws_iam_role.ec2.name
}
