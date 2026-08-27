variable "cluster_name" {
  description = "Name of the EKS cluster used by the AWS Load Balancer Controller."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer URL without the https:// prefix."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the controller."
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account used by the controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "role_name" {
  description = "IAM role assumed by the controller service account."
  type        = string
}

variable "policy_arn" {
  description = "Existing IAM policy attached to the controller role."
  type        = string
}
variable "aws_region" {
  description = "AWS region where the EKS cluster is deployed."
  type        = string
}
variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed."
  type        = string
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}

