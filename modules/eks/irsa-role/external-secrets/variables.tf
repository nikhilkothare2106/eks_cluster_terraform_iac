variable "role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (e.g. arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<oidc_id>)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster's OIDC provider, without the https:// prefix (e.g. oidc.eks.ap-south-1.amazonaws.com/id/<oidc_id>)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
}

# variable "policy_arns" {
#   description = "List of IAM policy ARNs to attach to the role"
#   type        = list(string)
# }

variable "tags" {
  description = "Tags to apply to the IAM role"
  type        = map(string)
  default     = {}
}

variable "secret_arn" {
  description = "ARN of the secret in Secrets Manager"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}
