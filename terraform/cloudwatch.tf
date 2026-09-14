resource "aws_cloudwatch_dashboard" "optimal_health" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "Chat Orchestrator Lambda"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            [
              "AWS/Lambda",
              "Invocations",
              "FunctionName",
              aws_lambda_function.chat_orchestrator.function_name,
              {
                stat  = "Sum"
                label = "Invocations"
              }
            ],
            [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              aws_lambda_function.chat_orchestrator.function_name,
              {
                stat  = "Sum"
                label = "Errors"
              }
            ],
            [
              "AWS/Lambda",
              "Throttles",
              "FunctionName",
              aws_lambda_function.chat_orchestrator.function_name,
              {
                stat  = "Sum"
                label = "Throttles"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "Chat Orchestrator Duration"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            [
              "AWS/Lambda",
              "Duration",
              "FunctionName",
              aws_lambda_function.chat_orchestrator.function_name,
              {
                stat  = "Average"
                label = "Average Duration"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "API Gateway Requests and Errors"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            [
              "AWS/ApiGateway",
              "Count",
              "ApiId",
              aws_apigatewayv2_api.staff_assistant.id,
              "Stage",
              aws_apigatewayv2_stage.prod.name,
              {
                stat  = "Sum"
                label = "Requests"
              }
            ],
            [
              "AWS/ApiGateway",
              "4xx",
              "ApiId",
              aws_apigatewayv2_api.staff_assistant.id,
              "Stage",
              aws_apigatewayv2_stage.prod.name,
              {
                stat  = "Sum"
                label = "4xx Errors"
              }
            ],
            [
              "AWS/ApiGateway",
              "5xx",
              "ApiId",
              aws_apigatewayv2_api.staff_assistant.id,
              "Stage",
              aws_apigatewayv2_stage.prod.name,
              {
                stat  = "Sum"
                label = "5xx Errors"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "API Gateway Latency"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            [
              "AWS/ApiGateway",
              "Latency",
              "ApiId",
              aws_apigatewayv2_api.staff_assistant.id,
              "Stage",
              aws_apigatewayv2_stage.prod.name,
              {
                stat  = "Average"
                label = "API Latency"
              }
            ],
            [
              "AWS/ApiGateway",
              "IntegrationLatency",
              "ApiId",
              aws_apigatewayv2_api.staff_assistant.id,
              "Stage",
              aws_apigatewayv2_stage.prod.name,
              {
                stat  = "Average"
                label = "Integration Latency"
              }
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          title   = "KB Sync Lambda"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 300

          metrics = [
            [
              "AWS/Lambda",
              "Invocations",
              "FunctionName",
              aws_lambda_function.kb_sync.function_name,
              {
                stat  = "Sum"
                label = "Invocations"
              }
            ],
            [
              "AWS/Lambda",
              "Errors",
              "FunctionName",
              aws_lambda_function.kb_sync.function_name,
              {
                stat  = "Sum"
                label = "Errors"
              }
            ]
          ]
        }
      }
    ]
  })
}