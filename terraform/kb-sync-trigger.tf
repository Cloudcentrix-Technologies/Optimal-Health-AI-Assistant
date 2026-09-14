# ============================================================
# S3 EVENT NOTIFICATION
# ============================================================
#
# When a document is uploaded to incoming/,
# S3 invokes the KB Sync Lambda.
# ============================================================


# ------------------------------------------------------------
# Allow Amazon S3 to invoke the Lambda function.
# ------------------------------------------------------------

resource "aws_lambda_permission" "allow_s3_kb_sync" {
  statement_id = "AllowS3InvokeKBsync"

  action = "lambda:InvokeFunction"

  function_name = aws_lambda_function.kb_sync.function_name

  principal = "s3.amazonaws.com"

  source_arn = aws_s3_bucket.knowledge_documents.arn

  source_account = data.aws_caller_identity.current.account_id
}


# ------------------------------------------------------------
# Configure the S3 bucket to invoke the Lambda when an object
# is created under incoming/.
# ------------------------------------------------------------

resource "aws_s3_bucket_notification" "knowledge_documents" {

  bucket = aws_s3_bucket.knowledge_documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.kb_sync.arn

    events = [
      "s3:ObjectCreated:*"
    ]

    filter_prefix = "incoming/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_kb_sync
  ]
}