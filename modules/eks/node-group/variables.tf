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

variable "node_role_arn" {
  type = string
}

variable "node_groups" {
  type = map(object({
    subnet_ids     = list(string)
    instance_types = list(string)
    capacity_type  = string
    ami_type       = string
    disk_size      = number
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
