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

variable "cluster_role_name" {
  description = "Existing IAM role name used by the EKS control plane."
  type        = string
}

variable "node_role_name" {
  description = "Existing IAM role name used by EKS managed node groups."
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
  description = "EKS addons to install. Map key is the addon name (e.g. vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver). Set version to null to use the most recent version."
  type = map(object({
    version                  = optional(string)
    resolve_conflicts        = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string)
    before_compute           = optional(bool, false) # <-- classification lives with the data
  }))
}


variable "create_oidc_provider" {
  description = "Create the IAM OIDC identity provider for the cluster, required for IRSA (IAM Roles for Service Accounts)."
  type        = bool
}

# ---------------------------
# Database module inputs
# ---------------------------
variable "postgresql_database_config" {
  description = "Configuration for the PostgreSQL RDS instance."
  type = object({
    name                    = string
    availability_zone       = string
    db_name                 = string
    username                = string
    password                = string
    port                    = number
    engine_version          = string
    instance_class          = string
    allocated_storage       = number
    storage_type            = string
    publicly_accessible     = bool
    skip_final_snapshot     = bool
    backup_retention_period = optional(number, 7)
  })
}

variable "mysql_database_config" {
  description = "Configuration for the MySQL RDS instance."
  type = object({
    name                    = string
    availability_zone       = string
    db_name                 = string
    username                = string
    password                = string
    port                    = number
    engine_version          = string
    instance_class          = string
    allocated_storage       = number
    storage_type            = string
    publicly_accessible     = bool
    skip_final_snapshot     = bool
    backup_retention_period = optional(number, 7)
  })
}

# ---------------------------
# Shared tags
# ---------------------------
variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
}
