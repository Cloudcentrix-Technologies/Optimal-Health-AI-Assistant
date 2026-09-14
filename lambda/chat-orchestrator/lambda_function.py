

import json
import os
import boto3
import botocore
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
MODEL_ID = os.environ["MODEL_ID"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ["GUARDRAIL_VERSION"]
MAX_RESULTS = int(os.environ.get("MAX_RESULTS", "5"))

bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")
bedrock_runtime = boto3.client("bedrock-runtime")

logger.info("Runtime boto3 version: %s", boto3.__version__)
logger.info("Runtime botocore version: %s", botocore.__version__)
logger.info(
    "Bedrock Agent Runtime client service model: %s",
    bedrock_agent_runtime.meta.service_model.service_name
)

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
MODEL_ID = os.environ["MODEL_ID"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ["GUARDRAIL_VERSION"]

MAX_RESULTS = int(os.environ.get("MAX_RESULTS", "5"))

# ------------------------------------------------------------
# AWS clients
# ------------------------------------------------------------

bedrock_agent_runtime = boto3.client("bedrock-agent-runtime")
bedrock_runtime = boto3.client("bedrock-runtime")

# ------------------------------------------------------------
# System prompt
# ------------------------------------------------------------

SYSTEM_PROMPT = """
You are the Optimal Health M&B Staff Knowledge Assistant.

You assist authorized staff by answering questions using the approved
organizational knowledge provided in the retrieved context.

Rules:
1. Answer using only information supported by the retrieved context.
2. Do not invent, assume, or fabricate information.
3. If the retrieved context does not contain enough information to answer
   the question, clearly say that the approved knowledge base does not
   contain enough information to answer the question.
4. Do not provide unsupported medical diagnoses, treatment decisions,
   prescriptions, or clinical instructions.
5. Keep responses clear, professional, and concise.
6. When useful, identify the relevant source document by name.
"""

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def extract_question(event):
    """
    Supports both direct Lambda invocation and API Gateway proxy events.
    """

    if not event:
        return None

    # Direct invocation:
    # {"question": "..."}
    if isinstance(event, dict):
        if event.get("question"):
            return str(event["question"])

        if event.get("query"):
            return str(event["query"])

    # API Gateway proxy event:
    # {"body": "{\"question\":\"...\"}"}
    body = event.get("body") if isinstance(event, dict) else None

    if body:
        if isinstance(body, str):
            try:
                body = json.loads(body)
            except json.JSONDecodeError:
                return body

        if isinstance(body, dict):
            if body.get("question"):
                return str(body["question"])

            if body.get("query"):
                return str(body["query"])

    return None


def retrieve_context(question):
    """
    Retrieve approved knowledge from the Bedrock Knowledge Base.

    This is a managed Knowledge Base, so retrieval uses
    managedSearchConfiguration rather than vectorSearchConfiguration.
    """

    response = bedrock_agent_runtime.retrieve(
        knowledgeBaseId=KNOWLEDGE_BASE_ID,
        retrievalConfiguration={
            "managedSearchConfiguration": {
                "numberOfResults": MAX_RESULTS
            }
        },
        retrievalQuery={
            "text": question
        }
    )

    results = response.get("retrievalResults", [])

    context_parts = []
    sources = []

    for result in results:
        content = result.get("content", {})
        text = content.get("text")

        if not text:
            continue

        context_parts.append(text)

        metadata = result.get("metadata", {})
        source_name = metadata.get("_document_title")

        if source_name and source_name not in sources:
            sources.append(source_name)

    return "\n\n".join(context_parts), sources


def generate_answer(question, context):
    """
    Generate a grounded response using Claude Sonnet 4.5.
    """

    user_prompt = f"""
Use the approved knowledge context below to answer the staff member's
question.

QUESTION:
{question}

APPROVED KNOWLEDGE CONTEXT:
{context}

Answer the question using only the approved knowledge context.
"""

    response = bedrock_runtime.converse(
        modelId=MODEL_ID,

        system=[
            {
                "text": SYSTEM_PROMPT
            }
        ],

        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "text": user_prompt
                    }
                ]
            }
        ],

        inferenceConfig={
            "maxTokens": 800,
            "temperature": 0.2
        },

        guardrailConfig={
            "guardrailIdentifier": GUARDRAIL_ID,
            "guardrailVersion": GUARDRAIL_VERSION,
            "trace": "disabled"
        }
    )

    output = response.get("output", {})
    message = output.get("message", {})
    content = message.get("content", [])

    answer_parts = []

    for item in content:
        if "text" in item:
            answer_parts.append(item["text"])

    return "\n".join(answer_parts).strip()


# ------------------------------------------------------------
# Lambda handler
# ------------------------------------------------------------

def lambda_handler(event, context):

    logger.info("Received event: %s", json.dumps(event))

    question = extract_question(event)

    if not question or not question.strip():
        return {
            "statusCode": 400,
            "body": json.dumps({
                "error": "A question or query is required."
            })
        }

    question = question.strip()

    try:
        # ----------------------------------------------------
        # 1. Retrieve approved knowledge
        # ----------------------------------------------------

        retrieved_context, sources = retrieve_context(question)

        logger.info(
            "Retrieved %d source documents for question.",
            len(sources)
        )

        # ----------------------------------------------------
        # 2. Generate grounded answer
        # ----------------------------------------------------

        if retrieved_context:
            answer = generate_answer(
                question,
                retrieved_context
            )
        else:
            answer = (
                "I don't have enough information in the approved "
                "knowledge base to answer that question."
            )

        # ----------------------------------------------------
        # 3. Return response
        # ----------------------------------------------------

        return {
            "statusCode": 200,
            "body": json.dumps({
                "answer": answer,
                "sources": sources
            })
        }

    except Exception as e:
        logger.exception("Chat Orchestrator failed.")

        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "The AI assistant could not process the request.",
                "details": str(e)
            })
        }