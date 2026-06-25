resource "kubectl_manifest" "karpenter_ec2_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: al2023@v1.33

      instanceProfile: ${var.node_instance_profile}

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${var.cluster_name}"

      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 50Gi
            volumeType: gp3
            encrypted: true
            deleteOnTermination: true

      tags:
        Environment: "${var.environment}"
        ManagedBy: terraform
        karpenter.sh/discovery: "${var.cluster_name}"
  YAML

  depends_on = [helm_release.karpenter]
}

# NodePool: system
# Para addons e ferramentas de plataforma (monitoring, logging, ingress, etc.)
# On-demand para garantir estabilidade. Taint impede pods de app de cair aqui.
resource "kubectl_manifest" "karpenter_node_pool_system" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: system
    spec:
      template:
        metadata:
          labels:
            node-role: system
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          taints:
            - key: node-role
              value: system
              effect: NoSchedule

          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]

            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]

            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["t3", "t3a", "m5", "m6i"]

            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["medium", "large", "xlarge"]

          expireAfter: 720h

      limits:
        cpu: "20"
        memory: 80Gi

      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 60s
  YAML

  depends_on = [kubectl_manifest.karpenter_ec2_node_class]
}

# NodePool: app
# Para workloads de aplicacao genericas. Spot + on-demand, familias variadas
# incluindo Graviton (arm64) para reducao de custo.
resource "kubectl_manifest" "karpenter_node_pool_app" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: app
    spec:
      template:
        metadata:
          labels:
            node-role: app
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          taints:
            - key: node-role
              value: app
              effect: NoSchedule

          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]

            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]

            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["t3", "t3a", "m5", "m5a", "m6i", "m6a", "c5", "c6i", "c6a"]

            - key: karpenter.k8s.aws/instance-size
              operator: NotIn
              values: ["nano", "micro", "small"]

          expireAfter: 720h

      limits:
        cpu: "60"
        memory: 240Gi

      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [kubectl_manifest.karpenter_ec2_node_class]
}

# NodePool: batch
# Para jobs pesados e workloads tolerantes a interrupcao.
# Spot apenas, instancias maiores CPU/memory optimized.
# WhenEmpty evita consolidacao agressiva durante execucao de jobs.
resource "kubectl_manifest" "karpenter_node_pool_batch" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: batch
    spec:
      template:
        metadata:
          labels:
            node-role: batch
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          taints:
            - key: node-role
              value: batch
              effect: NoSchedule

          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]

            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]

            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["c5", "c6i", "c6a", "m5", "m6i", "r5", "r6i"]

            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["large", "xlarge", "2xlarge", "4xlarge"]

          expireAfter: 720h

      limits:
        cpu: "80"
        memory: 320Gi

      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [kubectl_manifest.karpenter_ec2_node_class]
}

# NodePool: geral
# Pool catch-all SEM taint — aceita qualquer pod que nao tenha nodeSelector definido.
# Util para workloads avulsos, legados ou times que ainda nao seguem as convencoes.
resource "kubectl_manifest" "karpenter_node_pool_geral" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: geral
    spec:
      template:
        metadata:
          labels:
            node-role: geral
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64", "arm64"]

            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]

            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["t3", "t3a", "m5", "m6i", "c5", "c6i"]

            - key: karpenter.k8s.aws/instance-size
              operator: NotIn
              values: ["nano", "micro", "small"]

          expireAfter: 720h

      limits:
        cpu: "40"
        memory: 160Gi

      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
  YAML

  depends_on = [kubectl_manifest.karpenter_ec2_node_class]
}
