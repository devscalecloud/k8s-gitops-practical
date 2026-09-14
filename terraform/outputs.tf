output "region" {
  description = "AWS region resources were deployed into."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group attached to the EKS control plane."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group attached to EKS worker nodes."
  value       = aws_security_group.nodes.id
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB placement)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS worker nodes)."
  value       = aws_subnet.private[*].id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider registered for this cluster. Needed to build the trust policy for any cluster add-on's IRSA role (AWS Load Balancer Controller, EBS CSI driver, etc)."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "update_kubeconfig_command" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}

output "account_id" {
  description = "AWS account ID resources were deployed into."
  value       = data.aws_caller_identity.current.account_id
}
