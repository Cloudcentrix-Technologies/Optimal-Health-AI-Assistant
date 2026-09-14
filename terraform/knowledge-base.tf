# ============================================================
# AMAZON BEDROCK MANAGED KNOWLEDGE BASE
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

# ------------------------------------------------------------
# Create the Bedrock Managed Knowledge Base.
#
# Amazon Bedrock manages:
# - Vector storage
# - Document indexing
# - Embeddings
# - Retrieval infrastructure
#
# We therefore do NOT need to create OpenSearch Serverless
# or another customer-managed vector database.
# ------------------------------------------------------------

resource "aws_bedrockagent_knowledge_base" "optimal_health" {
  name = "${var.project_name}-kb-${var.environment}"

  description = "Managed Knowledge Base for the Optimal Health M&B AI Staff Knowledge Assistant."

  role_arn = aws_iam_role.bedrock_knowledge_base.arn

  knowledge_base_configuration {
    # MANAGED tells Bedrock to manage the Knowledge Base
    # storage and retrieval infrastructure.
    type = "MANAGED"

    managed_knowledge_base_configuration {
      # Use the Bedrock service-managed embedding model.
      #
      # We are intentionally not specifying Titan or another
      # customer-selected embedding model here.
      embedding_model_type = "MANAGED"
    }
  }

  tags = {
    Name        = "${var.project_name}-kb-${var.environment}"
    Environment = var.environment
    Purpose     = "Optimal Health staff knowledge retrieval"
  }
}