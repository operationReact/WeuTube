# A dedicated WeuTube Cognito user pool for JWT authentication.
# A real administrator must be provisioned into the weutube-admin group;
# toggling "Admin Demo" in the Flutter prototype never grants access.
resource "aws_cognito_user_pool" "weutube" {
  count = var.enable_api ? 1 : 0
  name  = "${local.prefix}-users"
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]
  mfa_configuration = "OPTIONAL"
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
resource "aws_cognito_user_pool_client" "weutube" {
  count = var.enable_api ? 1 : 0
  name = "${local.prefix}-creator"
  user_pool_id = aws_cognito_user_pool.weutube[0].id
  generate_secret = false
  explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
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
