# ============================================================
# API GATEWAY
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

resource "aws_apigatewayv2_api" "staff_assistant" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API for the Optimal Health M&B AI Staff Knowledge Assistant."

  cors_configuration {
    allow_headers = [
      "content-type",
      "authorization"
    ]

    allow_methods = [
      "POST",
      "OPTIONS"
    ]

    allow_origins = ["*"]
  }

  tags = {
    Name        = "${var.project_name}-api-${var.environment}"
    Environment = var.environment
    Purpose     = "Staff AI Assistant API"
  }

  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}

resource "aws_apigatewayv2_integration" "chat_orchestrator" {
  api_id = aws_apigatewayv2_api.staff_assistant.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.chat_orchestrator.invoke_arn
  integration_method = "POST"

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "chat" {
  api_id = aws_apigatewayv2_api.staff_assistant.id

  route_key = "POST /chat"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id

  target = "integrations/${aws_apigatewayv2_integration.chat_orchestrator.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id = aws_apigatewayv2_api.staff_assistant.id

  name        = "$default"
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = true
  }
  tags = {
    Name        = "${var.project_name}-api-stage-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id = "AllowAPIGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.chat_orchestrator.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.staff_assistant.execution_arn}/*/*"
}

output "api_gateway_url" {
  description = "HTTP API endpoint for the Optimal Health AI Staff Assistant."
  value       = aws_apigatewayv2_stage.prod.invoke_url
}