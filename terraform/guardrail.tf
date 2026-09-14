# ============================================================
# AMAZON BEDROCK GUARDRAIL
# Optimal Health M&B AI Staff Knowledge Assistant
# ============================================================

resource "aws_bedrock_guardrail" "optimal_health" {
  name = "${var.project_name}-guardrail-${var.environment}"

  description = "Safety and privacy guardrail for the Optimal Health M&B AI Staff Knowledge Assistant."

  # Message returned when an incoming user request is blocked.
  blocked_input_messaging = "This request cannot be handled by the AI assistant. Please refer the matter to the appropriate qualified staff member or clinician."

  # Message returned when the model generates content that is blocked.
  blocked_outputs_messaging = "The requested response cannot be provided by the AI assistant. Please refer the matter to the appropriate qualified staff member or clinician."

  # ----------------------------------------------------------
  # Content safety policy
  # ----------------------------------------------------------
  #
  # MISCONDUCT is enabled for both user input and model output.
  #
  # Prompt-attack protection is intentionally not configured
  # here because the current Bedrock API requires PROMPT_ATTACK
  # to be configured as an input-only filter.
  # ----------------------------------------------------------

  content_policy_config {
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }

  # ----------------------------------------------------------
  # Sensitive information / PII protection
  # ----------------------------------------------------------
  #
  # These entities are blocked in both incoming requests and
  # model responses.
  #
  # This provides an additional privacy layer for the assistant.
  # It does NOT replace the document approval process before
  # documents are added to the Knowledge Base.
  # ----------------------------------------------------------

  sensitive_information_policy_config {
    pii_entities_config {
      type          = "EMAIL"
      action        = "BLOCK"
      input_action  = "BLOCK"
      output_action = "BLOCK"
    }

    pii_entities_config {
      type          = "PHONE"
      action        = "BLOCK"
      input_action  = "BLOCK"
      output_action = "BLOCK"
    }

    pii_entities_config {
      type          = "ADDRESS"
      action        = "BLOCK"
      input_action  = "BLOCK"
      output_action = "BLOCK"
    }

    pii_entities_config {
      type          = "NAME"
      action        = "BLOCK"
      input_action  = "BLOCK"
      output_action = "BLOCK"
    }
  }

  # ----------------------------------------------------------
  # Resource tags
  # ----------------------------------------------------------


  tags = {
    Name        = "${var.project_name}-guardrail-${var.environment}"
    Environment = var.environment
    Purpose     = "AI safety and privacy controls"
  }

  lifecycle {
    ignore_changes = [
      tags["aws-apn-id"]
    ]
  }
}

resource "aws_bedrock_guardrail_version" "optimal_health" {
  guardrail_arn = aws_bedrock_guardrail.optimal_health.guardrail_arn
  description   = "Production safety policy for Optimal Health M&B AI Staff Knowledge Assistant."
  skip_destroy  = true
}