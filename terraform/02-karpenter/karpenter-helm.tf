resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version

  wait    = true
  timeout = 300

  values = [
    templatefile("${path.module}/helm/karpenter/values.yaml.tpl", {
      cluster_name     = var.cluster_name
      cluster_endpoint = data.aws_eks_cluster.this.endpoint
    })
  ]
}
