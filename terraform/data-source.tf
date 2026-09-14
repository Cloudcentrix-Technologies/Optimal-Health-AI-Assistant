# ============================================================
# BEDROCK KNOWLEDGE BASE DATA SOURCE
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================
#
# IMPORTANT:
# The Knowledge Base is intentionally restricted to the
# approved/ prefix.
#
# Documents placed anywhere else in the S3 bucket are NOT
# ingested into the Knowledge Base.
# ============================================================

resource "aws_bedrockagent_data_source" "optimal_health_documents" {
  name = "${var.project_name}-documents-${var.environment}"

  description = "Approved Optimal Health M&B documents for the staff AI knowledge assistant."

  knowledge_base_id = aws_bedrockagent_knowledge_base.optimal_health.id

  data_source_configuration {
    type = "MANAGED_KNOWLEDGE_BASE_CONNECTOR"

    managed_knowledge_base_connector_configuration {
      connector_parameters = jsonencode({
        type    = "S3"
        version = "1"

        connectionConfiguration = {
          bucketName           = aws_s3_bucket.knowledge_documents.bucket
          bucketOwnerAccountId = data.aws_caller_identity.current.account_id
        }

        # ----------------------------------------------------
        # DOCUMENT CONTROL BOUNDARY
        # ----------------------------------------------------
        #
        # Bedrock will only ingest objects under approved/.
        #
        # Files uploaded to incoming/, rejected/, or any other
        # prefix will not be ingested.
        # ----------------------------------------------------

        filterConfiguration = {
          inclusionPrefixes      = ["approved/"]
          maxFileSizeInMegaBytes = "500"
        }

        aclEnabled = false
      })

      # ------------------------------------------------------
      # MEDIA EXTRACTION
      # ------------------------------------------------------
      #
      # Enables image extraction during Knowledge Base
      # ingestion for supported documents.
      # ------------------------------------------------------

      media_extraction_configuration {
        image_extraction_configuration {
          image_extraction_status = "ENABLED"
        }
      }
    }
  }

  vector_ingestion_configuration {
    parsing_configuration {
      parsing_strategy = "SMART_PARSING"
    }
  }
}