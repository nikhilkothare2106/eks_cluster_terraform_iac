variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster; also used as a prefix for every related resource."
  type        = string
  default     = "eks-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
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

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "endpoint_private_access" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "Managed node groups to create. See modules/eks/variables.tf for the full object schema."
  type        = any
  default = {
    default = {
      instance_types = ["m7i-flex.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      disk_size      = 20
    }
  }
}

variable "cluster_addons" {
  type = map(object({
    version                  = optional(string, null)
    resolve_conflicts        = optional(string, "OVERWRITE")
    service_account_role_arn = optional(string, null)
  }))
 
}

variable "create_oidc_provider" {
  description = "Create the IAM OIDC identity provider for the cluster, required for IRSA (IAM Roles for Service Accounts)."
  type        = bool
}


variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    Project = "eks-platform"
  }
}
