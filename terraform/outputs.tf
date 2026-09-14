# ------------------------------------------------------------
# S3 bucket information
# ------------------------------------------------------------

output "knowledge_documents_bucket_name" {
  description = "Name of the S3 bucket containing approved knowledge documents."
  value       = aws_s3_bucket.knowledge_documents.bucket
}

output "knowledge_documents_bucket_arn" {
  description = "ARN of the S3 knowledge documents bucket."
  value       = aws_s3_bucket.knowledge_documents.arn
}

# ------------------------------------------------------------
# IAM role outputs
# ------------------------------------------------------------

output "bedrock_knowledge_base_role_arn" {
  description = "IAM role ARN used by the Bedrock Knowledge Base."
  value       = aws_iam_role.bedrock_knowledge_base.arn
}

output "chat_orchestrator_role_arn" {
  description = "IAM role ARN used by the Chat Orchestrator Lambda."
  value       = aws_iam_role.chat_orchestrator.arn
}

output "kb_sync_role_arn" {
  description = "IAM role ARN used by the KB Sync Lambda."
  value       = aws_iam_role.kb_sync.arn
}
# ------------------------------------------------------------
# KB Sync Lambda
# ------------------------------------------------------------

output "kb_sync_lambda_arn" {
  description = "ARN of the Knowledge Base Sync Lambda."
  value       = aws_lambda_function.kb_sync.arn
}

output "kb_sync_lambda_name" {
  description = "Name of the Knowledge Base Sync Lambda."
  value       = aws_lambda_function.kb_sync.function_name
}
# ------------------------------------------------------------
# Chat Orchestrator Lambda
# ------------------------------------------------------------

output "chat_orchestrator_lambda_arn" {
  description = "ARN of the Chat Orchestrator Lambda."
  value       = aws_lambda_function.chat_orchestrator.arn
}

output "chat_orchestrator_lambda_name" {
  description = "Name of the Chat Orchestrator Lambda."
  value       = aws_lambda_function.chat_orchestrator.function_name
}