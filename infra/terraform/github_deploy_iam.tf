# Optional GitHub Actions OIDC role. The target AWS account must already
# have the IAM OIDC provider token.actions.githubusercontent.com registered.
variable "github_oidc_provider_arn" {
  description = "Existing AWS IAM GitHub Actions OIDC provider ARN; empty disables deploy role."
  type = string
  default = ""
}
resource "aws_iam_role" "github_api_deploy" {
  count = var.enable_api && var.github_oidc_provider_arn != "" ? 1 : 0
  name = "${local.prefix}-github-api-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = var.github_oidc_provider_arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:operationReact@215111824/WeuTube@1458924161:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_api_deploy" {
  count = var.enable_api && var.github_oidc_provider_arn != "" ? 1 : 0
  name = "deploy-api-artifacts-and-ssm"
  role = aws_iam_role.github_api_deploy[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.api_artifacts[0].arn}/releases/*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.api[0].id}",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::document/AWS-RunShellScript"
        ]
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetCommandInvocation"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/client-id",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/client-secret",
          "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/token-key-base64"
        ]
      }
    ]
  })
}

output "github_api_deploy_role_arn" {
  value = var.enable_api && var.github_oidc_provider_arn != "" ? aws_iam_role.github_api_deploy[0].arn : null
}
