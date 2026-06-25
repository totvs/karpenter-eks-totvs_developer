output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_version" {
  description = "Versão do Kubernetes no cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Certificado CA do cluster (base64)"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Comando para atualizar o kubeconfig local"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  description = "ID da VPC utilizada pelo cluster"
  value       = local.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas utilizadas pelo cluster"
  value       = local.private_subnets
}
