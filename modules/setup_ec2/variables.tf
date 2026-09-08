variable "key_name" {
  description = "Base name used for the setup EC2 key pair and generated private key."
  type        = string
}

variable "subnet_id" {
  type = string
}
variable "ec2_sg" {
  type = string
}