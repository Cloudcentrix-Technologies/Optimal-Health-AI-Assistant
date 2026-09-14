# ------------------------------------------------------------

# S3 bucket for approved Optimal Health knowledge documents

# ------------------------------------------------------------

resource "aws_s3_bucket" "knowledge_documents" {
  bucket = "${var.project_name}-documents-${var.environment}"

  tags = {
    Name        = "${var.project_name}-documents-${var.environment}"
    Environment = var.environment
    Purpose     = "Approved documents for Bedrock Knowledge Base"
  }
  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}

# ------------------------------------------------------------

# Enable default server-side encryption for all objects

# uploaded to the bucket.

# ------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "knowledge_documents" {
  bucket = aws_s3_bucket.knowledge_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ------------------------------------------------------------

# Prevent public access to the knowledge document bucket.

# ------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "knowledge_documents" {
  bucket = aws_s3_bucket.knowledge_documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------

# Keep previous versions of documents so accidental changes

# or overwrites can be recovered.

# ------------------------------------------------------------

resource "aws_s3_bucket_versioning" "knowledge_documents" {
  bucket = aws_s3_bucket.knowledge_documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================

# DOCUMENT CONTROL PREFIXES

# ============================================================

#

# S3 does not have traditional folders. These empty objects

# create the prefixes used by the document-control workflow.

#

# incoming/  = documents awaiting validation

# approved/  = documents eligible for Knowledge Base ingestion

# rejected/  = documents that failed validation

# ============================================================

resource "aws_s3_object" "incoming_prefix" {
  bucket = aws_s3_bucket.knowledge_documents.id
  key    = "incoming/.keep"

  content = ""

  tags = {
    Environment = var.environment
    Purpose     = "Documents awaiting validation"
  }
}

resource "aws_s3_object" "approved_prefix" {
  bucket = aws_s3_bucket.knowledge_documents.id
  key    = "approved/.keep"

  content = ""

  tags = {
    Environment = var.environment
    Purpose     = "Approved documents for Knowledge Base ingestion"
  }
}

resource "aws_s3_object" "rejected_prefix" {
  bucket = aws_s3_bucket.knowledge_documents.id
  key    = "rejected/.keep"

  content = ""

  tags = {
    Environment = var.environment
    Purpose     = "Documents rejected during validation"
  }
}

