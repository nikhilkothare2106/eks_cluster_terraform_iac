variable "name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane, e.g. \"1.31\". Check currently supported versions before applying."
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN the EKS control plane assumes (from the iam module)."
  type        = string
}

# ---------------------------
# Networking
# ---------------------------
variable "subnet_ids" {
  description = "Subnet IDs passed to ResourcesVpcConfig.SubnetIds — normally BOTH public and private subnets, matching the reference CFN template."
  type        = list(string)
}

variable "control_plane_security_group_ids" {
  description = "Additional security group IDs attached to the cluster (from the security-group module's control_plane_additional SG)."
  type        = list(string)
}

variable "shared_node_security_group_id" {
  description = "Shared node security group ID (from the security-group module). Used to wire up the cross ingress rules between the cluster's managed SG and the nodes."
  type        = string
}

variable "endpoint_private_access" {
  type = bool
}

variable "endpoint_public_access" {
  type = bool
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public API endpoint, when endpoint_public_access = true."
  type        = list(string)
}

# ---------------------------
# Access / auth
# ---------------------------
variable "authentication_mode" {
  description = "One of API, API_AND_CONFIG_MAP, CONFIG_MAP."
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "bootstrap_cluster_creator_admin_permissions" {
  type    = bool
  default = true
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types to ship to CloudWatch Logs."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ---------------------------
# Node groups
# ---------------------------
variable "node_groups" {
  description = <<-EOT
    Map of managed node groups to create. Key is the node group name.
  EOT
  type = map(object({
    subnet_ids     = list(string)
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND") # ON_DEMAND | SPOT
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    disk_size      = optional(number, 20)
    min_size       = number
    max_size       = number
    desired_size   = number
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string # NO_SCHEDULE | PREFER_NO_SCHEDULE | NO_EXECUTE
    })), [])
    node_role_arn = optional(string, null) # falls back to var.default_node_role_arn
  }))
  default = {}
}

variable "default_node_role_arn" {
  description = "IAM role ARN used by node groups that don't set their own node_role_arn (from the iam module's node role)."
  type        = string
  default     = null
}

# ---------------------------
# Addons
# ---------------------------
variable "cluster_addons" {
  description = "EKS addons to install. Map key is the addon name (e.g. vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver). Set version to null to use the most recent version."
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
  type    = map(string)
  default = {}
}
