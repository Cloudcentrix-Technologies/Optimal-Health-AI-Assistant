# Optimal Health M&B — AI Staff Knowledge Assistant

An internal AI knowledge assistant that enables staff to securely query approved medical, beauty, service, and operational information through a retrieval-augmented generation workflow built on AWS.

The solution uses Amazon Cognito for staff authentication, Amazon API Gateway and AWS Lambda for the application layer, Amazon Bedrock with Claude Sonnet 4.5 for response generation, Amazon Bedrock Knowledge Bases for document retrieval, and Amazon S3 for governed knowledge document storage. Infrastructure is provisioned and managed entirely through Terraform.

## Architecture

```text
                              Staff
                               │
                               ▼
                       Staff Web Browser
                               │
                               ▼
                    Amazon Cognito
                    Staff Authentication
                               │
                               ▼
                    Amazon API Gateway
                               │
                               ▼
                 AWS Lambda: Chat Orchestrator
                               │
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
          Amazon Bedrock           Knowledge Base
        Claude Sonnet 4.5        Retrieval / Search
                    │                     │
                    └──────────┬──────────┘
                               │
                               ▼
                    Grounded AI Response
                               │
                               ▼
                              Staff


        Approved Knowledge Documents
                    │
                    ▼
                Amazon S3
       Medical • Beauty • Service • Ops
                    │
                    │ Upload / Update
                    ▼
             AWS Lambda: KB Sync
                    │
                    ▼
        Amazon Bedrock Knowledge Base
              Re-index / Sync


             Amazon CloudWatch
        Logs • Metrics • Dashboard
```

## AWS Services Used

| Service                        | Purpose                                       |
| ------------------------------ | --------------------------------------------- |
| Amazon Cognito                 | Staff authentication                          |
| Amazon API Gateway             | Secure API endpoint for the assistant         |
| AWS Lambda                     | Chat Orchestrator and KB Sync processing      |
| Amazon Bedrock                 | Claude Sonnet 4.5 inference                   |
| Amazon Bedrock Knowledge Bases | Retrieval of approved knowledge documents     |
| Amazon S3                      | Storage and governance of knowledge documents |
| AWS IAM                        | Service and application permissions           |
| Amazon CloudWatch              | Logs, metrics, monitoring, and dashboard      |
| AWS Amplify                    | Frontend hosting                              |

## Key Features

### Retrieval-Augmented Generation

Staff questions are processed by the Chat Orchestrator, which retrieves relevant information from the approved Knowledge Base before generating a response with Claude Sonnet 4.5.

This keeps responses grounded in the organization's approved knowledge rather than relying solely on the model's general knowledge.

### Governed Knowledge Documents

Knowledge documents are stored in Amazon S3 and processed through a controlled document workflow.

Documents uploaded for processing are validated by the KB Sync Lambda and separated into approved and rejected locations. Only documents in the approved document path are indexed by the Knowledge Base.

### AI Guardrails

Amazon Bedrock Guardrails are applied to the AI response workflow to provide an additional safety control around generated responses.

The solution is designed as an internal knowledge assistant and does not replace professional medical judgement or organizational review.

### Staff Authentication

Amazon Cognito provides authentication for staff accessing the assistant through the web interface.

### Centralized Monitoring

Amazon CloudWatch provides operational visibility through Lambda and API Gateway metrics, logs, and a dedicated dashboard.

The dashboard includes:

* Lambda invocations
* Lambda errors
* Lambda throttles
* Lambda execution duration
* API Gateway request counts
* API Gateway 4xx and 5xx errors
* API Gateway latency
* API integration latency
* KB Sync Lambda activity

## Repository Structure

```text
optimal-health-ai-assistant/

├── terraform/
│   ├── api-gateway.tf
│   ├── cloudwatch.tf
│   ├── cognito.tf
│   ├── iam.tf
│   ├── knowledge-base.tf
│   ├── lambda.tf
│   ├── s3.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── ...
│
├── lambda/
│   ├── chat-orchestrator/
│   └── kb-sync/
│
├── frontend-ui/
│
├── .gitignore
└── README.md
```

## Infrastructure as Code

The AWS environment is provisioned and managed using Terraform.

Terraform manages the application's AWS infrastructure, including:

* Amazon Cognito
* Amazon API Gateway
* AWS Lambda
* Amazon Bedrock integration
* Amazon Bedrock Knowledge Bases
* Amazon S3
* IAM roles and policies
* Amazon CloudWatch
* Amazon Amplify configuration

## Getting Started

Initialize Terraform:

```bash
cd terraform
terraform init
```

Review the deployment:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

The deployment uses the configured AWS region and AWS CLI profile defined in the Terraform variables.

## Knowledge Document Workflow

The knowledge document workflow is designed to ensure that only approved content is available for retrieval.

```text
Document Upload
      │
      ▼
Amazon S3
   incoming/
      │
      ▼
AWS Lambda: KB Sync
      │
      ├───────────────┐
      │               │
      ▼               ▼
 approved/         rejected/
      │
      ▼
Knowledge Base
   Re-index
```

The Knowledge Base uses the approved document location as its data source scope.

## Security

Security controls include:

* Amazon Cognito authentication
* IAM least-privilege permissions for application components
* Restricted S3 access to required document paths
* Controlled Knowledge Base document scope
* Amazon Bedrock Guardrails
* CloudWatch operational logging and monitoring
* Human review of AI-generated information where appropriate

## Frontend

The staff-facing web interface is hosted using Amazon Amplify.

The frontend authenticates staff through Amazon Cognito and sends authenticated requests to the API Gateway endpoint.

Amplify is used only for frontend hosting. The solution does not use a separate CloudFront distribution.

## Monitoring

Amazon CloudWatch provides operational visibility across the application.

The Terraform-managed dashboard includes:

* Chat Orchestrator Lambda invocations
* Lambda errors
* Lambda throttles
* Lambda duration
* API Gateway request volume
* API Gateway 4xx errors
* API Gateway 5xx errors
* API Gateway latency
* API integration latency
* KB Sync Lambda invocations
* KB Sync Lambda errors

## Validation

The solution was validated through:

* Terraform validation and deployment
* API Gateway configuration verification
* Cognito authentication configuration
* Lambda deployment verification
* Knowledge Base retrieval testing
* Chat Orchestrator testing
* Knowledge document approval and rejection workflow testing
* CloudWatch logging verification
* CloudWatch dashboard deployment

## Solution Boundaries

The solution does not use:

* Amazon Bedrock Agents
* Bedrock Agent action groups
* Amazon EC2
* Amazon ECS
* Amazon RDS
* Amazon DynamoDB
* A dedicated VPC
* A separate CloudFront distribution

The solution uses Amazon Amplify for frontend hosting.

AI responses are generated from retrieved organizational knowledge and remain subject to appropriate human review and organizational policies.

## Business Value

The solution enables Optimal Health M&B to:

* Provide staff with faster access to approved organizational knowledge
* Reduce time spent searching across internal documents
* Improve consistency of information retrieval
* Introduce governed Generative AI into internal workflows
* Maintain document control through an approval-based knowledge workflow
* Improve operational visibility through centralized monitoring
* Establish a repeatable AWS-based foundation for future AI use cases
