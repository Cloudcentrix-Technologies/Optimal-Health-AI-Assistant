# ============================================================
# CHAT ORCHESTRATOR LAMBDA
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

data "archive_file" "chat_orchestrator" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/chat-orchestrator"
  output_path = "${path.module}/../lambda/chat-orchestrator.zip"
}

resource "aws_lambda_function" "chat_orchestrator" {
  function_name = "${var.project_name}-chat-orchestrator-${var.environment}"

  description = "RAG-based Chat Orchestrator for the Optimal Health M&B Staff Knowledge Assistant."

  role = aws_iam_role.chat_orchestrator.arn

  handler = "lambda_function.lambda_handler"

  runtime = "python3.12"

  filename = data.archive_file.chat_orchestrator.output_path

  source_code_hash = data.archive_file.chat_orchestrator.output_base64sha256

  timeout = 60

  memory_size = 512

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = "O2APGMXFIE"

      MODEL_ID = "us.anthropic.claude-sonnet-4-5-20250929-v1:0"

      GUARDRAIL_ID = "ym41bc2m1c4j"

      GUARDRAIL_VERSION = "1"

      MAX_RESULTS = "5"
    }
  }

  tags = {
    Name        = "${var.project_name}-chat-orchestrator-${var.environment}"
    Environment = var.environment
    Purpose     = "Knowledge retrieval and grounded AI response generation"
  }

  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}