# Optimal Health M&B AI Staff Knowledge Assistant

## Overview

The Optimal Health M&B AI Staff Knowledge Assistant is an internal Generative AI application that helps staff retrieve information from approved medical, beauty, service, and operational documents.

The solution uses Amazon Bedrock with Anthropic Claude Sonnet 4.5 through a cross-Region inference profile, together with Amazon Bedrock Knowledge Bases for retrieval-augmented generation. Staff authenticate through Amazon Cognito and interact with the assistant through a web application hosted on Amazon Amplify Hosting.

## Architecture

The solution is deployed in AWS Region `us-east-1`.

### Main request flow

```text
Staff Web Browser
       |
       v
Amazon Cognito
       |
       | Authenticated request
       v
Amazon API Gateway
       |
       v
AWS Lambda
Chat Orchestrator
       |
       +------------------------------+
       |                              |
       v                              v
Amazon Bedrock                 Amazon Bedrock
Inference Profile              Knowledge Bases
Claude Sonnet 4.5              Managed RAG
       |                              |
       +---------------+--------------+
                       |
                       v
              Grounded AI Response
                       |
                       v
                 Staff Browser
```

The Chat Orchestrator retrieves relevant information from the managed Amazon Bedrock Knowledge Base before sending the retrieved context to Claude Sonnet 4.5 for response generation.

The model is accessed through the following Bedrock inference profile:

```text
us.anthropic.claude-sonnet-4-5-20250929-v1:0
```

The underlying foundation model is:

```text
anthropic.claude-sonnet-4-5-20250929-v1
```

### Knowledge document flow

```text
Staff / Approved Document Source
              |
              v
       Amazon S3 Bucket
              |
              v
          incoming/
              |
              v
       AWS Lambda
       KB Sync
              |
        +-----+-----+
        |           |
        v           v
    approved/    rejected/
        |
        v
Amazon Bedrock
Knowledge Bases
        |
        v
Managed Knowledge
Base Index
```

Documents uploaded to the `incoming/` S3 prefix are processed by the Knowledge Base Sync Lambda.

Documents containing the required approval metadata are moved to `approved/`. Documents that do not meet the approval requirement are moved to `rejected/`.

The Bedrock Knowledge Base data source is configured to index only the `approved/` prefix.

## AWS Services

### Amazon Bedrock

Amazon Bedrock provides the Generative AI inference layer.

The Chat Orchestrator uses Anthropic Claude Sonnet 4.5 through a Bedrock inference profile:

```text
us.anthropic.claude-sonnet-4-5-20250929-v1:0
```

The inference profile is used by the Lambda function for response generation.

### Amazon Bedrock Knowledge Bases

The solution uses a **managed Amazon Bedrock Knowledge Base** to implement retrieval-augmented generation.

The Knowledge Base retrieves relevant content from approved organizational documents before the content is passed to the language model.

Current Knowledge Base configuration:

```text
Knowledge Base ID: O2APGMXFIE
Data Source ID:    79ZZF7NY0E
```

The S3 data source is restricted to:

```text
approved/
```

The application uses the managed Knowledge Base retrieval configuration and requests up to five relevant results for each query.

### Amazon S3

Amazon S3 stores the organization's knowledge documents.

The document workflow uses three logical prefixes:

```text
incoming/
approved/
rejected/
```

Only documents under `approved/` are available to the Knowledge Base data source.

### AWS Lambda

Two Lambda functions support the application.

#### Chat Orchestrator

The Chat Orchestrator:

1. Receives authenticated API requests.
2. Queries Amazon Bedrock Knowledge Bases.
3. Retrieves relevant document content.
4. Builds the model request using the retrieved context.
5. Invokes Claude Sonnet 4.5 through the Bedrock inference profile.
6. Applies the configured Bedrock Guardrail.
7. Returns the generated response to the staff application.

Function:

```text
optimal-health-ai-assistant-chat-orchestrator-prod
```

Runtime:

```text
Python 3.12
```

Configuration includes:

```text
Knowledge Base ID: O2APGMXFIE
Model ID:          us.anthropic.claude-sonnet-4-5-20250929-v1:0
Max Results:       5
```

#### Knowledge Base Sync Lambda

The Knowledge Base Sync Lambda manages document approval and routing.

It is triggered by S3 events for objects uploaded under:

```text
incoming/
```

The function checks the document approval metadata.

Approved documents are moved to:

```text
approved/
```

Documents that do not satisfy the approval requirement are moved to:

```text
rejected/
```

This ensures that the Knowledge Base indexes only approved organizational content.

### Amazon Cognito

Amazon Cognito provides authentication for staff accessing the application.

The deployed user pool is:

```text
Region:       us-east-1
User Pool ID: us-east-1_tg5bBaPVj
```

The frontend uses the Cognito application client to authenticate users before making requests to the API.

### Amazon API Gateway

Amazon API Gateway exposes the chat API used by the frontend.

The API requires an authenticated Cognito token before allowing requests to reach the Chat Orchestrator Lambda.

The deployed API endpoint is configured for the application in `frontend-ui/app.js`.

### AWS IAM

AWS IAM provides access control for the application components.

The Lambda execution roles grant permissions required for:

* Amazon Bedrock Knowledge Base retrieval
* Amazon Bedrock model invocation
* Amazon Bedrock Guardrails
* Amazon S3 document processing
* Required supporting AWS services

Permissions are scoped to the resources required by each Lambda function.

### Amazon CloudWatch

Amazon CloudWatch provides operational logging for the Lambda functions and supports troubleshooting and monitoring of the deployed application.

### AWS Amplify Hosting

Amazon Amplify Hosting is used to host the frontend web application.

Amplify is only used for frontend hosting. It is not part of the backend request-processing path.

The frontend is located in:

```text
frontend-ui/
```

## AI Model and Inference

The application uses Anthropic Claude Sonnet 4.5 through Amazon Bedrock.

The deployed inference profile is:

```text
us.anthropic.claude-sonnet-4-5-20250929-v1:0
```

The Lambda function first retrieves relevant information from the Bedrock Knowledge Base and then provides that retrieved context to the model.

The application prompt instructs the model to:

* Use the retrieved organizational context when answering.
* Avoid inventing information.
* Avoid unsupported claims.
* Clearly indicate when relevant information is not available.
* Avoid providing unsupported medical diagnoses, treatments, or prescriptions.

## Amazon Bedrock Guardrail

The Chat Orchestrator uses an Amazon Bedrock Guardrail as an additional safety control during model interaction.

Configured Guardrail:

```text
Guardrail ID:      ym41bc2m1c4j
Guardrail Version: 1
```

The guardrail is applied during the Bedrock model interaction to provide an additional layer of control around generated responses.

## Knowledge Base Configuration

The application uses a managed Amazon Bedrock Knowledge Base with an Amazon S3 data source.

```text
Knowledge Base
O2APGMXFIE
      |
      v
S3 Data Source
79ZZF7NY0E
      |
      v
s3://optimal-health-ai-assistant-documents-prod/approved/
```

The Knowledge Base is configured to retrieve relevant content from the approved document collection.

The application does not directly send the entire S3 document collection to the model. Relevant content is retrieved through the Bedrock Knowledge Base before model generation.

## Document Governance

The document workflow separates incoming documents from approved knowledge sources.

```text
incoming/
    |
    v
KB Sync Lambda
    |
    +---- approved/ ----> Bedrock Knowledge Base
    |
    +---- rejected/
```

Documents uploaded to `incoming/` must contain the required approval metadata.

The expected S3 metadata is:

```text
Key:   approval-status
Value: approved
```

Only approved documents are moved to the `approved/` prefix and indexed by the Knowledge Base.

This provides a controlled workflow for determining which organizational information can be used by the AI assistant.

## Authentication and Security

The application uses Amazon Cognito to authenticate staff.

Authenticated requests are sent to Amazon API Gateway with a Cognito token.

API Gateway validates the authentication token before invoking the Chat Orchestrator Lambda.

AWS IAM roles control access between the application components.

The repository does not contain:

* AWS access keys
* AWS secret keys
* User passwords
* Authentication tokens
* Terraform state files
* Generated deployment ZIP packages
* Local test outputs

The Cognito application client ID and API endpoint used by the frontend are application configuration values and are not AWS credentials.

## Frontend

The frontend is a lightweight web application located in:

```text
frontend-ui/
```

It contains:

```text
frontend-ui/
├── app.js
├── index.html
└── styles.css
```

The frontend:

1. Authenticates the staff user through Amazon Cognito.
2. Obtains an authenticated session.
3. Sends the staff question to API Gateway.
4. Receives the response from the Chat Orchestrator.
5. Displays the grounded response to the user.

Amazon Amplify Hosting provides the web hosting layer.

## Infrastructure as Code

The AWS infrastructure is provisioned and managed using Terraform.

Terraform configuration is located in:

```text
terraform/
```

Terraform manages resources including:

* Amazon S3
* Amazon Cognito
* Amazon API Gateway
* AWS Lambda
* Amazon Bedrock Knowledge Bases
* Amazon Bedrock Guardrails
* IAM roles and policies
* S3 event notifications
* Supporting AWS resources

The repository also contains `.terraform.lock.hcl` to maintain consistent provider versions.

Terraform state files and the local `.terraform/` directory are intentionally excluded from version control.

## Repository Structure

```text
Optimal-Health-AI-Assistant/
│
├── frontend-ui/
│   ├── app.js
│   ├── index.html
│   └── styles.css
│
├── lambda/
│   ├── chat-orchestrator/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── six.py
│   │
│   └── kb-sync/
│       └── lambda_function.py
│
├── terraform/
│   ├── api-gateway.tf
│   ├── chat-orchestrator-lambda.tf
│   ├── cognito.tf
│   ├── data-source.tf
│   ├── guardrail.tf
│   ├── iam.tf
│   ├── kb-sync-lambda.tf
│   ├── kb-sync-trigger.tf
│   ├── knowledge-base.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── variables.tf
│
├── .gitignore
└── README.md
```

## Validation

The deployed solution was validated through:

* Cognito authentication testing
* API authorization testing
* Authenticated chat requests
* Amazon Bedrock Knowledge Base retrieval testing
* Approved document workflow testing
* Rejected document workflow testing
* S3 document ingestion testing
* End-to-end frontend testing

Knowledge Base retrieval was tested using staff-oriented questions and returned relevant information from approved organizational documents.

An example retrieval test asked:

```text
What should staff do if a client reports a reaction after treatment?
```

The Knowledge Base returned relevant content from the approved medical and safety documentation, including escalation, incident reporting, and appropriate response procedures.

## Deployment

The infrastructure can be deployed using Terraform.

From the Terraform directory:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

The AWS provider is configured for the target deployment environment.

The current deployment uses the AWS CLI profile:

```text
optimal-health
```

The profile is configured locally and should not contain credentials in the repository.

After the infrastructure is deployed, the frontend can be deployed through Amazon Amplify Hosting.

## Repository Exclusions

The following files and directories are intentionally excluded from version control:

* Terraform state files
* `.terraform/`
* Local Terraform variable files
* Lambda deployment ZIP packages
* Frontend deployment ZIP packages
* Python `__pycache__/` directories
* Python compiled files
* Local test outputs
* Retrieval test files
* Operating system files
* IDE configuration files

## Scope and Architecture Boundaries

This implementation uses a retrieval-augmented generation architecture based on Amazon Bedrock Knowledge Bases.

The solution does **not** use:

* Amazon Bedrock Agents
* Bedrock Agent action groups
* Amazon EC2
* Amazon ECS
* Amazon RDS
* Amazon DynamoDB
* A dedicated VPC architecture
* A separate CloudFront distribution
* Automatic publishing of AI-generated content

Amazon Amplify Hosting is used for frontend hosting only.

The backend uses Amazon API Gateway, AWS Lambda, Amazon Bedrock, Amazon Bedrock Knowledge Bases, Amazon S3, Amazon Cognito, IAM, and CloudWatch.

Human staff remain responsible for reviewing and acting on information provided by the assistant, particularly where operational or medical decisions are involved.
