variable "name" {
  description = "Name prefix used for tagging all network resources (e.g. the EKS cluster name)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "enable_dns_support" {
  type    = bool
  default = true
}

# Map keyed by a logical subnet name (e.g. "SubnetPublicAPSOUTH1A") so it mirrors
# the eksctl-generated CloudFormation template and is easy to reason about.
variable "subnet_config" {
  description = " Map of subnets to create. Key is a logical name, value defines cidr_block,availability zone and whether it is public."

  type = map(object({
    cidr_block = string
    az         = string
    public     = bool
  }))

  validation {
    condition = (
      length([for subnet in var.subnet_config : subnet if subnet.public]) > 0 &&
      length([for subnet in var.subnet_config : subnet if !subnet.public]) > 0
    )
    error_message = "subnet_config must contain at least one public and one private subnet."
  }

  validation {
    condition = var.single_nat_gateway || alltrue([
      for private_az in distinct([for subnet in var.subnet_config : subnet.az if !subnet.public]) :
      contains([for subnet in var.subnet_config : subnet.az if subnet.public], private_az)
    ])
    error_message = "When single_nat_gateway is false, every AZ with a private subnet must also have a public subnet."
  }

}

variable "single_nat_gateway" {
  description = "If true (default, matches the reference CFN template's 'Single' NAT mode) create ONE NAT Gateway shared by all private route tables. If false, create one NAT Gateway per AZ that has a public subnet (highly available, costs more)."
  type        = bool
}

variable "map_public_ip_on_launch" {
  description = "Auto-assign public IPs on instances launched in public subnets."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags applied to every resource in this module."
  type        = map(string)
  default     = {}
}
