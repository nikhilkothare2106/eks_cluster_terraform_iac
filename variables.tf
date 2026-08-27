# =====================================================================
# ROOT INPUTS — values are supplied in terraform.tfvars.
# =====================================================================

# ---------------------------
# Global settings
# ---------------------------
variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster; also used as a prefix for every related resource."
  type        = string
}

# ---------------------------
# Network module inputs
# ---------------------------
variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  description = "true = one shared NAT Gateway (cheaper, matches the reference CFN template). false = one NAT Gateway per AZ (more resilient, costs more)."
  type        = bool
  default     = true
}

variable "subnet_config" {
  description = "CIDR and AZ of Subnets"
  type = map(object({
    cidr_block = string
    az         = string
    public     = bool
  }))
}

# ---------------------------
# EKS module inputs
# ---------------------------
variable "kubernetes_version" {
  type = string
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "endpoint_private_access" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type = list(string)
}

variable "node_groups" {
  description = "Managed node groups to create. See modules/eks/variables.tf for the full object schema."
  type        = any
}

variable "cluster_addons" {
  type = map(object({
    version                  = optional(string)
    resolve_conflicts        = optional(string)
    service_account_role_arn = optional(string)
  }))
}

variable "create_oidc_provider" {
  description = "Create the IAM OIDC identity provider for the cluster, required for IRSA (IAM Roles for Service Accounts)."
  type        = bool
}

# ---------------------------
# External Secrets IRSA module inputs
# ---------------------------
variable "external_store_secret_arn" {
  description = "ARN of the myapp dev secret in Secrets Manager"
  type        = string
}


variable "external_secrets_irsa_role_name" {
  description = "Name of the IAM role to create"
  type        = string
}

variable "external_secrets_namespace" {
  description = "Kubernetes namespace of the service account"
  type        = string
}

variable "external_secrets_service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
}

# ---------------------------
# Shared tags
# ---------------------------
variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
}

# ---------------------------
# AWS Load Balancer Controller IRSA module inputs
# ---------------------------
variable "alb_irsa_policy_arn" {
  description = "Existing IAM policy attached to the controller role."
  type        = string
}
variable "alb_irsa_namespace" {
  description = "Kubernetes namespace for the controller."
  type        = string
}

variable "alb_irsa_role_name" {
  description = "value"
  type        = string
}

# ---------------------------
# Argo CD module inputs
# ---------------------------
variable "argocd_chart_version" {
  description = "Optional pinned Argo CD chart version."
  type        = string
}

variable "argocd_values" {
  description = "YAML documents passed to the Argo CD Helm chart."
  type        = list(string)
}

variable "argocd_create_namespace" {
  description = "Create the Argo CD namespace when it does not exist."
  type        = bool
  default     = true
}

variable "argocd_wait" {
  description = "Wait for Argo CD resources to become ready."
  type        = bool
  default     = true
}

variable "argocd_atomic" {
  description = "Roll back the release if installation fails."
  type        = bool
  default     = true
}

variable "argocd_cleanup_on_fail" {
  description = "Delete newly created resources if the release fails."
  type        = bool
  default     = true
}

variable "argocd_timeout" {
  description = "Maximum time in seconds to wait for the Argo CD Helm release."
  type        = number
}