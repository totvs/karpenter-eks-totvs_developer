variable "aws_region" {
  description = "Região AWS onde o cluster está"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Nome do cluster EKS (deve corresponder ao criado em 01-eks)"
  type        = string
}

variable "karpenter_chart_version" {
  description = "Versão do Helm chart do Karpenter"
  type        = string
  default     = "1.0.6"
}

variable "node_instance_profile" {
  description = "Nome do Instance Profile que os nodes provisionados pelo Karpenter assumirão"
  type        = string
  default     = "eks-cluster-role"
}

variable "karpenter_node_iam_role_arn" {
  description = "ARN do IAM Role dos nodes que o Karpenter vai provisionar (usado no iam:PassRole)"
  type        = string
}

