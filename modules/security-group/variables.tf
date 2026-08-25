variable "name" {
  description = "Name prefix, typically the EKS cluster name."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID the security groups are created in."
  type        = string
}

variable "additional_control_plane_ingress_rules" {
  description = <<-EOT
    Extra ingress rules to attach to the control-plane additional security
    group (e.g. allow your office CIDR to reach the API server on 443, or a
    bastion host). Map key is just a logical name.
  EOT
  type = map(object({
    description       = string
    from_port         = number
    to_port           = number
    protocol          = string
    cidr_blocks       = optional(list(string), [])
    security_group_id = optional(string, null)
  }))
  default = {}
}

variable "additional_node_ingress_rules" {
  description = <<-EOT
    Extra ingress rules to attach to the shared node security group (e.g.
    allow SSH from a bastion, allow ALB/ingress-controller health checks
    from 0.0.0.0/0 on NodePort range).
  EOT
  type = map(object({
    description       = string
    from_port         = number
    to_port           = number
    protocol          = string
    cidr_blocks       = optional(list(string), [])
    security_group_id = optional(string, null)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
