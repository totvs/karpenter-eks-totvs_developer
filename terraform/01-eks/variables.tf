variable "aws_region" {
  description = "Região AWS onde o cluster será criado"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "eks-cluster-dev"
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "initial_node_count" {
  description = "Número de nodes do node group inicial"
  type        = number
  default     = 2
}

variable "initial_node_instance_type" {
  description = "Tipo de instância do node group inicial"
  type        = string
  default     = "t3.medium"
}

variable "eks_cluster_iam_role_arn" {
  description = "ARN do IAM Role existente para o control plane do EKS"
  type        = string
}

variable "eks_node_iam_role_arn" {
  description = "ARN do IAM Role existente para os nodes do EKS"
  type        = string
}

variable "create_vpc" {
  description = "Se true, cria uma nova VPC. Se false, usa uma VPC existente."
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID de uma VPC existente (obrigatório quando create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_private_subnet_ids" {
  description = "IDs das subnets privadas existentes (obrigatório quando create_vpc = false)"
  type        = list(string)
  default     = []
}
