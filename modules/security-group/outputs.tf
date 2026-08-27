output "control_plane_additional_security_group_id" {
  description = "Additional SG attached to the cluster's ResourcesVpcConfig (equivalent to ControlPlaneSecurityGroup in the CFN template)."
  value       = aws_security_group.control_plane_additional.id
}

output "shared_node_security_group_id" {
  description = "Shared SG attached to every node group (equivalent to ClusterSharedNodeSecurityGroup in the CFN template)."
  value       = aws_security_group.shared_node.id
}

output "setup_ec2_security_group_id" {
  description = "Security group ID attached to the setup EC2 instance."
  value       = aws_security_group.setup_ec2.id
}
