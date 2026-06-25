settings:
  clusterName: ${cluster_name}
  clusterEndpoint: ${cluster_endpoint}

controller:
  resources:
    requests:
      cpu: "1"
      memory: 1Gi
    limits:
      cpu: "1"
      memory: 1Gi

tolerations:
  - key: CriticalAddonsOnly
    operator: Exists
    effect: NoSchedule

nodeSelector:
  role: system
