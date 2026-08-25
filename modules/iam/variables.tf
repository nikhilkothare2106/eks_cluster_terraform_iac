variable "name" {
  description = "Name prefix, typically the EKS cluster name."
  type        = string
}

variable "cluster_service_role_additional_policy_arns" {
  description = "Extra managed policy ARNs to attach to the cluster service role, beyond AmazonEKSClusterPolicy and AmazonEKSVPCResourceController."
  type        = list(string)
  default     = []
}

variable "create_node_role" {
  description = "Whether to create the IAM role used by managed node groups."
  type        = bool
  default     = true
}

variable "node_role_additional_policy_arns" {
  description = "Extra managed policy ARNs to attach to the node group role, beyond the standard EKS worker node policies."
  type        = list(string)
  default     = []
}

variable "enable_ssm_on_nodes" {
  description = "Attach AmazonSSMManagedInstanceCore to the node role so you can use Session Manager instead of SSH."
  type        = bool
  default     = true
}

variable "create_fargate_role" {
  description = "Whether to create the IAM role used by Fargate profiles."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
