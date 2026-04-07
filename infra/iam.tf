 resource "aws_iam_openid_connect_provider" "github" {
    url             = "https://token.actions.githubusercontent.com"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  }
 
 resource "aws_iam_role" "github_actions" {
    name = "github-actions-eks-deploy"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:gustavobanares/aws-eks-infra:*"
            } 
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
          }
        }
      ]
    })
  }

 resource "aws_iam_role_policy" "github_actions_eks" {
    name = "github-actions-eks-policy"
    role = aws_iam_role.github_actions.id

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "eks:*",
            "ec2:*",
            "iam:*",
            "logs:*",
            "kms:*"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            "arn:aws:s3:::tptech-onboarding-tfstate",
            "arn:aws:s3:::tptech-onboarding-tfstate/*"
          ]
        }
      ]
    })
  }
  