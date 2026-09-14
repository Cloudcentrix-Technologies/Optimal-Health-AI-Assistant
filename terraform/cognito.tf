# ============================================================
# AMAZON COGNITO
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

resource "aws_cognito_user_pool" "staff" {
  name = "${var.project_name}-staff-${var.environment}"

  username_attributes = ["email"]

  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "OptimalHealth M&B Staff Account Verification"
    email_message        = "Your verification code is {####}."
  }

  tags = {
    Name        = "${var.project_name}-staff-${var.environment}"
    Environment = var.environment
    Purpose     = "Staff authentication for the AI Knowledge Assistant"
  }

  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}

resource "aws_cognito_user_pool_client" "staff_web" {
  name = "${var.project_name}-staff-web-${var.environment}"

  user_pool_id = aws_cognito_user_pool.staff.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id = aws_apigatewayv2_api.staff_assistant.id

  authorizer_type = "JWT"
  name            = "${var.project_name}-cognito-authorizer-${var.environment}"

  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    audience = [
      aws_cognito_user_pool_client.staff_web.id
    ]

    issuer = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.staff.id}"
  }
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for staff authentication."
  value       = aws_cognito_user_pool.staff.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN."
  value       = aws_cognito_user_pool.staff.arn
}

output "cognito_staff_client_id" {
  description = "Cognito App Client ID used by the staff web application."
  value       = aws_cognito_user_pool_client.staff_web.id
}