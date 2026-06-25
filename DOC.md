# Contexto do Projeto

## Objetivo
Criar infraestrutura AWS com EKS e Karpenter via Terraform e Helm.

## Stack
- Terraform >= 1.5
- AWS Provider >= 5.0
- Kubernetes Provider
- Helm Provider
- EKS versão 1.30
- Karpenter v1.x (usa NodePool + EC2NodeClass)

## Requisitos do Cluster EKS
- Nome: eks-cluster-dev
- Region: us-east-1 (ajustar conforme necessário)
- Node group inicial: 2 nodes fixos (on-demand, t3.medium)
- VPC: criar nova VPC com subnets públicas e privadas
- Nodes workers em subnets privadas
- Autenticação: aws-auth ConfigMap gerenciado pelo Terraform

## Requisitos do Karpenter
- Instalar via Helm chart oficial
- Versão: 1.x
- Usar IRSA (IAM Roles for Service Accounts)
- Criar NodePool padrão com:
  - instâncias spot e on-demand
  - famílias: t3, t3a, m5, m5a
  - SO: AL2023
- Criar EC2NodeClass vinculada ao cluster
- Remover Cluster Autoscaler se existir

## Estrutura de Arquivos Esperada
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── vpc.tf
├── eks.tf
├── karpenter.tf (IRSA + Helm)
└── karpenter-nodepool.tf (NodePool + EC2NodeClass via kubectl/helm)

## Observações
- Usar módulos terraform-aws-modules/eks e terraform-aws-modules/vpc
- Tags padrão em todos os recursos: Environment=dev, ManagedBy=terraform
- Outputs importantes: cluster_name, cluster_endpoint, kubeconfig command
