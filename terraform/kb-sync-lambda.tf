# ============================================================
# KB SYNC LAMBDA
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

# ------------------------------------------------------------
# Package the Python Lambda code into a ZIP file.
# ------------------------------------------------------------

data "archive_file" "kb_sync" {
  type        = "zip"
  source_file = "${path.module}/../lambda/kb-sync/lambda_function.py"
  output_path = "${path.module}/../lambda/kb-sync/kb-sync.zip"
}


# ------------------------------------------------------------
# Create the KB Sync Lambda function.
# ------------------------------------------------------------

resource "aws_lambda_function" "kb_sync" {
  function_name = "${var.project_name}-kb-sync-${var.environment}"

  description = "Validates and controls documents before they enter the Bedrock Knowledge Base."

  role = aws_iam_role.kb_sync.arn

  handler = "lambda_function.lambda_handler"

  runtime = "python3.12"

  filename = data.archive_file.kb_sync.output_path

  source_code_hash = data.archive_file.kb_sync.output_base64sha256

  timeout = 60

  memory_size = 256

  environment {
    variables = {
      APPROVED_PREFIX = "approved/"
      REJECTED_PREFIX = "rejected/"
    }
  }

  tags = {
    Name        = "${var.project_name}-kb-sync-${var.environment}"
    Environment = var.environment
    Purpose     = "Knowledge Base document validation and control"
  }

  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}