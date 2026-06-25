# ---------------------------------------------------------------------------
# Karpenter Controller — EKS Pod Identity
#
# Role criado sob o path /eng-roles/ com PermissionsBoundary obrigatório,
# conforme a policy manage-roles da conta (Sid: ManageRolesWithBoundary).
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "karpenter_pod_identity_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name                 = "karpenter-controller"
  path                 = "/eng-roles/"
  permissions_boundary = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/roles-boundary-old"
  assume_role_policy   = data.aws_iam_policy_document.karpenter_pod_identity_assume_role.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "Karpenter"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ec2:DescribeImages",
      "ec2:RunInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateTags",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:DescribeSpotPriceHistory",
      "pricing:GetProducts",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ConditionalEC2Termination"
    effect  = "Allow"
    actions = ["ec2:TerminateInstances"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "PassNodeIAMRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.karpenter_node_iam_role_arn]
  }

  statement {
    sid     = "EKSClusterEndpointLookup"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    ]
  }

  statement {
    sid       = "AllowInstanceProfileReadActions"
    effect    = "Allow"
    actions   = ["iam:GetInstanceProfile"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name   = "karpenter-controller-policy"
  role   = aws_iam_role.karpenter_controller.id
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

# Associa o role ao service account do Karpenter via Pod Identity
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = var.cluster_name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn

  depends_on = [helm_release.karpenter]
}
