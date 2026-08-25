output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = [for s in local.public_subnets : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs."
  value       = [for s in local.private_subnets : s.id]
}

output "private_azs" {
  description = "List of private subnet IDs."
  value       = local.private_azs
}

output "all_subnet_ids" {
  description = "List of all subnet IDs (public + private) — used for the EKS cluster's ResourcesVpcConfig, matching the reference CFN template."
  value       = [for s in aws_subnet.subnets : s.id]
}

output "subnets_by_name" {
  description = "Map of logical subnet name => subnet object, for advanced consumers."
  value       = aws_subnet.subnets
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_ids" {
  value = [for rt in aws_route_table.private : rt.id]
}

output "nat_gateway_ids" {
  value = [for nat in aws_nat_gateway.this : nat.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}
