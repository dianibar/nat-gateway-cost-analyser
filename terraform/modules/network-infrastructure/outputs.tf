output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_ips" {
  description = "NAT Gateway Elastic IPs"
  value       = aws_eip.nat[*].public_ip
}

#output "eks_cluster_name" {
#  description = "EKS cluster name"
#  value       = aws_eks_cluster.main.name
#}
#
#output "eks_cluster_endpoint" {
#  description = "EKS cluster endpoint"
#  value       = aws_eks_cluster.main.endpoint
#}
#
#output "eks_cluster_version" {
#  description = "EKS cluster version"
#  value       = aws_eks_cluster.main.version
#}
#
#output "eks_cluster_arn" {
#  description = "EKS cluster ARN"
#  value       = aws_eks_cluster.main.arn
#}
#
#output "eks_cluster_security_group_id" {
#  description = "EKS cluster security group ID"
#  value       = aws_security_group.eks_control_plane.id
#}
#
#output "eks_node_group_id" {
#  description = "EKS node group ID"
#  value       = aws_eks_node_group.main.id
#}
