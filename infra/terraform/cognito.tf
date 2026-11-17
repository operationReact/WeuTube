# A dedicated WeuTube Cognito user pool for JWT authentication.
# A real administrator must be provisioned into the weutube-admin group;
# toggling "Admin Demo" in the Flutter prototype never grants access.
resource "aws_cognito_user_pool" "weutube" {
  count = var.enable_api ? 1 : 0
  name  = "${local.prefix}-users"
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration {
    enabled = true
  }
  password_policy {
    minimum_length = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers = true
    require_symbols = true
    temporary_password_validity_days = 7
  }
  account_recovery_setting {
    recovery_mechanism {
      name = "verified_email"
      priority = 1
    }
  }
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }
}
# Google user sign-in is a distinct OAuth integration from YouTube channel grants.
# Google login credentials are provisioned in the production AWS account.
# Keep enabled for ALL subsequent production Terraform plans; silently reverting
# this setting would disconnect Google users from their login provider.
# Place its credentials in SSM SecureString (never in Terraform variables or Git).
variable "enable_google_login" {
  type = bool
  default = true
}
data "aws_ssm_parameter" "google_login_client_id" {
  count = var.enable_api && var.enable_google_login ? 1 : 0
  name = "/weutube/prod/google-login/client-id"
  with_decryption = true
}
data "aws_ssm_parameter" "google_login_client_secret" {
  count = var.enable_api && var.enable_google_login ? 1 : 0
  name = "/weutube/prod/google-login/client-secret"
  with_decryption = true
}
resource "aws_cognito_identity_provider" "google" {
  count = var.enable_api && var.enable_google_login ? 1 : 0
  user_pool_id = aws_cognito_user_pool.weutube[0].id
  provider_name = "Google"
  provider_type = "Google"
  provider_details = {
    authorize_scopes = "openid email profile"
    client_id = data.aws_ssm_parameter.google_login_client_id[0].value
    client_secret = data.aws_ssm_parameter.google_login_client_secret[0].value
  }
  attribute_mapping = {
    email = "email"
    name = "name"
  }
}
resource "aws_cognito_user_pool_domain" "login" {
  count = var.enable_api ? 1 : 0
  domain = "${local.prefix}-login-098859530205"
  user_pool_id = aws_cognito_user_pool.weutube[0].id
}
resource "aws_cognito_user_pool_client" "weutube" {
  count = var.enable_api ? 1 : 0
  name = "${local.prefix}-creator"
  user_pool_id = aws_cognito_user_pool.weutube[0].id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  # Keep existing USER_PASSWORD_AUTH and refresh flow enabled alongside PKCE.
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "profile"]
  callback_urls = [
    "weutube://auth-callback",
    "https://weutube.com/auth.html",
    "https://www.weutube.com/auth.html"
  ]
  logout_urls = ["https://weutube.com/", "https://www.weutube.com/"]
  supported_identity_providers = var.enable_google_login ? ["COGNITO", "Google"] : ["COGNITO"]
  depends_on = [aws_cognito_identity_provider.google]
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation = true
  access_token_validity = 60
  id_token_validity = 60
  refresh_token_validity = 30
  token_validity_units {
    access_token = "minutes"
    id_token = "minutes"
    refresh_token = "days"
  }
}
resource "aws_cognito_user_group" "admin" {
  count = var.enable_api ? 1 : 0
  name = "weutube-admin"
  user_pool_id = aws_cognito_user_pool.weutube[0].id
  description = "May initiate and view YouTube channel OAuth connections"
}
output "cognito_user_pool_id" {
  value = var.enable_api ? aws_cognito_user_pool.weutube[0].id : null
}
output "cognito_client_id" {
  value = var.enable_api ? aws_cognito_user_pool_client.weutube[0].id : null
}
output "cognito_issuer_uri" {
  value = var.enable_api ? "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.weutube[0].id}" : null
}

output "google_login_enabled" {
  value = var.enable_api && var.enable_google_login
}
output "cognito_login_domain" {
  value = var.enable_api ? "https://${aws_cognito_user_pool_domain.login[0].domain}.auth.${var.aws_region}.amazoncognito.com" : ""
}
