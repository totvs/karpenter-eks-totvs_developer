module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # Desabilita OIDC provider — usamos EKS Pod Identity em vez de IRSA
  enable_irsa = false

  cluster_addons = {
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  create_iam_role = false
  iam_role_arn    = var.eks_cluster_iam_role_arn

  eks_managed_node_groups = {
    initial = {
      name           = "initial-ng"
      instance_types = [var.initial_node_instance_type]

      create_iam_role = false
      iam_role_arn    = var.eks_node_iam_role_arn

      min_size     = var.initial_node_count
      max_size     = var.initial_node_count + 2
      desired_size = var.initial_node_count

      capacity_type = "ON_DEMAND"
      subnet_ids    = local.private_subnets

      labels = {
        role = "system"
      }

      taints = [
        {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
}
