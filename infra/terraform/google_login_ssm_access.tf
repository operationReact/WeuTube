# Only the GitHub OIDC Terraform bootstrap role may decrypt the two
# separately provisioned Google *user sign-in* OAuth credentials.
# The YouTube publishing-channel keys remain independent.
variable "google_login_terraform_role_name" {
  type        = string
  description = "Existing WeuTube GitHub OIDC Terraform bootstrap role."
  default     = "weutube-prod-terraform-github"
  validation {
    condition     = can(regex("^weutube-prod-[A-Za-z0-9_+=,.@-]+$", var.google_login_terraform_role_name))
    error_message = "Use an existing project-scoped WeuTube Terraform IAM role name."
  }
}

resource "aws_iam_role_policy" "google_login_parameter_reader" {
  count = var.enable_api ? 1 : 0
  name  = "weutube-prod-google-login-ssm-reader"
  role  = var.google_login_terraform_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadOnlyGoogleUserSignInSecrets"
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = [
        "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/google-login/client-id",
        "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/google-login/client-secret"
      ]
    }]
  })
}
