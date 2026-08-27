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
# Shared tags
# ---------------------------
variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
}
