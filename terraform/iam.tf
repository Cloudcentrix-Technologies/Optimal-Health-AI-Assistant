# ============================================================
# IAM CONFIGURATION
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

# ------------------------------------------------------------
# Get the AWS account ID where Terraform is deploying.
# We use this to restrict IAM permissions to this account.
# ------------------------------------------------------------

data "aws_caller_identity" "current" {}


# ============================================================
# BEDROCK KNOWLEDGE BASE
# ============================================================

resource "aws_iam_role" "bedrock_knowledge_base" {
  name = "${var.project_name}-bedrock-kb-role-${var.environment}"

  # ----------------------------------------------------------
  # Allow Amazon Bedrock to assume this role.
  # The conditions ensure that only Bedrock Knowledge Bases
  # from this AWS account can assume the role.
  # ----------------------------------------------------------

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


# ------------------------------------------------------------
# Allow the Bedrock Knowledge Base to list objects only within
# the approved/ document prefix.
# ------------------------------------------------------------

resource "aws_iam_role_policy" "bedrock_knowledge_base_s3" {
  name = "${var.project_name}-bedrock-kb-s3-${var.environment}"

  role = aws_iam_role.bedrock_knowledge_base.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ListApprovedKnowledgeDocuments"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

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

      # --------------------------------------------------------
      # Allow the Knowledge Base to read approved documents.
      # It cannot read documents from incoming/ or rejected/.
      # --------------------------------------------------------

      {
        Sid    = "ReadApprovedKnowledgeDocuments"
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

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

  # ----------------------------------------------------------
  # Allow AWS Lambda to assume this execution role.
  # ----------------------------------------------------------

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


# ------------------------------------------------------------
# Allow the Chat Orchestrator Lambda to write logs to
# Amazon CloudWatch Logs.
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "chat_orchestrator_logs" {
  role       = aws_iam_role.chat_orchestrator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ------------------------------------------------------------
# Allow the Chat Orchestrator Lambda to retrieve information
# from the approved Bedrock Knowledge Base, invoke Claude
# Sonnet 4.5, apply the production Guardrail, and enable
# first-time AWS Marketplace model access through Bedrock.
# ------------------------------------------------------------

resource "aws_iam_role_policy" "chat_orchestrator_bedrock" {
  name = "${var.project_name}-chat-orchestrator-bedrock-${var.environment}"

  role = aws_iam_role.chat_orchestrator.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ------------------------------------------------------
      # Retrieve information from the approved Knowledge Base.
      # ------------------------------------------------------

      {
        Sid    = "KnowledgeBaseRetrieve"
        Effect = "Allow"

        Action = [
          "bedrock:Retrieve"
        ]

        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/O2APGMXFIE"
      },


      # ------------------------------------------------------
      # Invoke Claude Sonnet 4.5 through the US inference
      # profile and its destination foundation models.
      # ------------------------------------------------------

      {
        Sid    = "InvokeClaudeSonnet45"
        Effect = "Allow"

        Action = [
          "bedrock:InvokeModel"
        ]

        Resource = [
          ""arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-sonnet-4-5-20250929-v1:0",

          "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",

          "arn:aws:bedrock:us-east-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",

          "arn:aws:bedrock:us-west-2::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0"
        ]
      },


      # ------------------------------------------------------
      # Allow the Lambda to apply the production Guardrail.
      # ------------------------------------------------------

      {
        Sid    = "ApplyGuardrail"
        Effect = "Allow"

        Action = [
          "bedrock:ApplyGuardrail"
        ]

        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:guardrail/ym41bc2m1c4j"
      },


      # ------------------------------------------------------
      # Allow Bedrock to complete the first-time AWS
      # Marketplace subscription/access flow for the
      # third-party Claude model.
      #
      # The condition prevents these Marketplace actions
      # from being used directly by the Lambda for unrelated
      # Marketplace operations. They are permitted only when
      # the request is made through Amazon Bedrock.
      # ------------------------------------------------------

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

  # ----------------------------------------------------------
  # Allow AWS Lambda to assume this execution role.
  # ----------------------------------------------------------

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


# ------------------------------------------------------------
# Allow the KB Sync Lambda to write logs to CloudWatch Logs.
# ------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "kb_sync_logs" {
  role       = aws_iam_role.kb_sync.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# ============================================================
# KB SYNC LAMBDA - DOCUMENT CONTROL PERMISSIONS
# ============================================================
#
# The KB Sync Lambda manages the document-control workflow:
#
# incoming/
#     ↓
# validation
#     ↓
# approved/ OR rejected/
#
# The Lambda does NOT have permission to modify arbitrary
# locations in the bucket.
# ============================================================

resource "aws_iam_role_policy" "kb_sync_s3" {
  name = "${var.project_name}-kb-sync-s3-${var.environment}"

  role = aws_iam_role.kb_sync.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ------------------------------------------------------
      # Allow the Lambda to list objects in incoming/.
      # ------------------------------------------------------

      {
        Sid    = "ListIncomingDocuments"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

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


      # ------------------------------------------------------
      # Allow the Lambda to read incoming documents.
      #
      # DeleteObject is also required because the Lambda moves
      # a processed document out of incoming/ after validation.
      #
      # It can ONLY delete objects under incoming/.
      # ------------------------------------------------------

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


      # ------------------------------------------------------
      # Allow the Lambda to place approved documents in the
      # approved/ prefix.
      # ------------------------------------------------------

      {
        Sid    = "WriteApprovedDocuments"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = "${aws_s3_bucket.knowledge_documents.arn}/approved/*"

        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },


      # ------------------------------------------------------
      # Allow the Lambda to place rejected documents in the
      # rejected/ prefix.
      # ------------------------------------------------------

      {
        Sid    = "WriteRejectedDocuments"
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

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