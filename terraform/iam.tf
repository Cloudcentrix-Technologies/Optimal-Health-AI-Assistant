# ============================================================
# IAM CONFIGURATION
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

data "aws_caller_identity" "current" {}

# ============================================================
# BEDROCK KNOWLEDGE BASE
# ============================================================

resource "aws_iam_role" "bedrock_knowledge_base" {
  name = "${var.project_name}-bedrock-kb-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "BedrockAssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "bedrock.amazonaws.com"
        }

        Action = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }

          ArnLike = {
            "AWS:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-bedrock-kb-role-${var.environment}"
    Environment = var.environment
    Purpose     = "Bedrock Managed Knowledge Base access"
  }
}

resource "aws_iam_role_policy" "bedrock_knowledge_base_s3" {
  name = "${var.project_name}-bedrock-kb-s3-${var.environment}"
  role = aws_iam_role.bedrock_knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListApprovedKnowledgeDocuments"
        Effect = "Allow"

        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.knowledge_documents.arn

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }

          StringLike = {
            "s3:prefix" = [
              "approved/",
              "approved/*"
            ]
          }
        }
      },
      {
        Sid    = "ReadApprovedKnowledgeDocuments"
        Effect = "Allow"

        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.knowledge_documents.arn}/approved/*"

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# ============================================================
# CHAT ORCHESTRATOR LAMBDA
# ============================================================

resource "aws_iam_role" "chat_orchestrator" {
  name = "${var.project_name}-chat-orchestrator-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "LambdaAssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-chat-orchestrator-role-${var.environment}"
    Environment = var.environment
    Purpose     = "Chat Orchestrator Lambda execution"
  }
}

resource "aws_iam_role_policy_attachment" "chat_orchestrator_logs" {
  role       = aws_iam_role.chat_orchestrator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "chat_orchestrator_bedrock" {
  name = "${var.project_name}-chat-orchestrator-bedrock-${var.environment}"
  role = aws_iam_role.chat_orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "KnowledgeBaseRetrieve"
        Effect = "Allow"

        Action   = ["bedrock:Retrieve"]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/O2APGMXFIE"
      },
      {
        Sid    = "InvokeClaudeSonnet45"
        Effect = "Allow"

        Action = ["bedrock:InvokeModel"]

        Resource = [
          "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
        ]
      },
      {
        Sid    = "ApplyGuardrail"
        Effect = "Allow"

        Action   = ["bedrock:ApplyGuardrail"]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:guardrail/ym41bc2m1c4j"
      },
      {
        Sid    = "MarketplaceModelAccess"
        Effect = "Allow"

        Action = [
          "aws-marketplace:Subscribe",
          "aws-marketplace:ViewSubscriptions"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:CalledViaLast" = "bedrock.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ============================================================
# KNOWLEDGE BASE SYNC LAMBDA
# ============================================================

resource "aws_iam_role" "kb_sync" {
  name = "${var.project_name}-kb-sync-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "LambdaAssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-kb-sync-role-${var.environment}"
    Environment = var.environment
    Purpose     = "Knowledge Base synchronization Lambda"
  }
}

resource "aws_iam_role_policy_attachment" "kb_sync_logs" {
  role       = aws_iam_role.kb_sync.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================
# KB SYNC LAMBDA - DOCUMENT CONTROL PERMISSIONS
#
# Workflow:
# incoming/ → validation → approved/ or rejected/
# ============================================================

resource "aws_iam_role_policy" "kb_sync_s3" {
  name = "${var.project_name}-kb-sync-s3-${var.environment}"
  role = aws_iam_role.kb_sync.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListIncomingDocuments"
        Effect = "Allow"

        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.knowledge_documents.arn

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }

          StringLike = {
            "s3:prefix" = [
              "incoming/",
              "incoming/*"
            ]
          }
        }
      },
      {
        Sid    = "ReadAndDeleteIncomingDocuments"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:DeleteObject"
        ]

        Resource = "${aws_s3_bucket.knowledge_documents.arn}/incoming/*"

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "WriteApprovedDocuments"
        Effect = "Allow"

        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.knowledge_documents.arn}/approved/*"

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "WriteRejectedDocuments"
        Effect = "Allow"

        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.knowledge_documents.arn}/rejected/*"

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}