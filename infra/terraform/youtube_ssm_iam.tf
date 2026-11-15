# A narrowly scoped read-only policy for the future Spring Boot workload IAM role.
# This policy does not attach itself to a role: the runtime role must be
# provisioned and attached when backend compute is deployed.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "youtube_oauth_parameters" {
  statement {
    sid     = "ReadWeuTubeYouTubeOAuthSecrets"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/client-id",
      "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/client-secret",
      "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/weutube/prod/youtube/token-key-base64"
    ]
  }
}

resource "aws_iam_policy" "youtube_oauth_parameters" {
  name        = "${local.prefix}-youtube-oauth-parameters"
  description = "Least privilege SSM reads for WeuTube's Google OAuth channel connector"
  policy      = data.aws_iam_policy_document.youtube_oauth_parameters.json
}

output "youtube_oauth_ssm_policy_arn" {
  description = "Attach this policy to the deployed Spring Boot runtime role"
  value       = aws_iam_policy.youtube_oauth_parameters.arn
}
