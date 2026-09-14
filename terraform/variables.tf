variable "aws_region" {
  description = "AWS region where the Optimal Health AI Assistant will be deployed."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used to deploy the solution."
  type        = string
  default     = "optimal-health"
}

variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "optimal-health-ai-assistant"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}