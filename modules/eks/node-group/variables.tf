variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_security_group_id" {
  type = string
}

variable "shared_node_security_group_id" {
  type = string
}

variable "node_groups" {
  type = map(object({
    subnet_ids     = list(string)
    instance_types = optional(list(string), ["t3.medium"])
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    disk_size      = optional(number, 20)
    min_size       = number
    max_size       = number
    desired_size   = number
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    node_role_arn = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
