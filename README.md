# Gestão Inteligente de Nós com Karpenter no Kubernetes

Material de referência da apresentação **TOTVS Developer** — *"Gestão Inteligente de Nós com Karpenter no Kubernetes"*.

Este repositório contém a infraestrutura como código (IaC) e os manifestos de deployment utilizados na demonstração prática da sessão.

---

## Sobre

O [Karpenter](https://karpenter.sh) é um autoscaler de nodes open-source, nativo do Kubernetes, criado pela AWS. Diferente do Cluster Autoscaler tradicional, ele provisiona instâncias EC2 diretamente — sem depender de Auto Scaling Groups fixos — escolhendo o tipo de instância mais eficiente para cada workload em segundos.

Esta demo mostra como estruturar um cluster EKS com múltiplos **NodePools** segmentados por perfil de carga, usando Spot e On-Demand de forma inteligente para reduzir custos mantendo disponibilidade.

---

## Arquitetura

```
┌──────────────────────────────────────────────────────────────────┐
│  AWS Account                                                     │
│                                                                  │
│  ┌──────────────────── VPC 10.0.0.0/16 (3 AZs) ──────────────┐  │
│  │                                                             │  │
│  │  ┌─────────────────── EKS Control Plane ────────────────┐  │  │
│  │  │                                                       │  │  │
│  │  │  Node Group inicial (t3.medium On-Demand)            │  │  │
│  │  │  ├── karpenter controller                            │  │  │
│  │  │  └── coredns                                         │  │  │
│  │  │                                                       │  │  │
│  │  │  NodePool: system  ──► monitoring / ingress          │  │  │
│  │  │  NodePool: app     ──► APIs / serviços web           │  │  │
│  │  │  NodePool: batch   ──► jobs / relatórios             │  │  │
│  │  │  NodePool: geral   ──► workloads sem nodeSelector    │  │  │
│  │  └───────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Estrutura do repositório

```
cluster-aws/
├── terraform/
│   ├── 01-eks/               # Módulo 1 — VPC + Cluster EKS + Node Group inicial
│   │   ├── main.tf
│   │   ├── vpc.tf
│   │   ├── eks.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   └── 02-karpenter/         # Módulo 2 — Helm do Karpenter + NodePools
│       ├── karpenter-helm.tf
│       ├── karpenter-nodepool.tf
│       ├── iam.tf
│       ├── main.tf
│       ├── variables.tf
│       └── versions.tf
└── deployment/
    └── karpenter/            # Deployments de exemplo por perfil de carga
        ├── api-ecommerce.yaml
        ├── portal-cliente.yaml
        ├── processador-relatorios.yaml
        └── stack-observabilidade.yaml
```

---

## NodePools

| NodePool | Perfil | Capacity Type | Famílias | Taint |
|---|---|---|---|---|
| `system` | Addons de plataforma (monitoring, ingress) | On-Demand | t3, t3a, m5, m6i | `node-role=system:NoSchedule` |
| `app` | APIs e serviços web | Spot + On-Demand | t3, m5, m6i, c5, c6i + Graviton | `node-role=app:NoSchedule` |
| `batch` | Jobs pesados e relatórios | Spot | c5, m5, r5 (large → 4xlarge) | `node-role=batch:NoSchedule` |
| `geral` | Workloads sem nodeSelector (catch-all) | Spot + On-Demand | t3, m5, m6i, c5, c6i | Sem taint |

---

## Exemplos de Deployment

Os arquivos em `deployment/karpenter/` ilustram como direcionar workloads para o NodePool correto usando `nodeSelector` e `tolerations`:

| Arquivo | Workload | NodePool alvo |
|---|---|---|
| `api-ecommerce.yaml` | API REST de e-commerce | `app` |
| `portal-cliente.yaml` | Portal web de clientes | `app` |
| `processador-relatorios.yaml` | Job de geração de relatórios | `batch` |
| `stack-observabilidade.yaml` | Prometheus / Grafana | `system` |

---

## Pré-requisitos

### Ferramentas locais

```bash
terraform version   # >= 1.5
aws --version       # AWS CLI v2
kubectl version --client
helm version        # >= 3.x
```

### Autenticação AWS

```bash
aws sts get-caller-identity
```

O usuário ou role precisa de permissões para criar VPC, EKS, IAM roles e recursos relacionados.

### IAM Roles necessárias

Antes de rodar o Terraform, crie (ou verifique que existem) as roles abaixo:

| Role | Finalidade |
|---|---|
| `eks-cluster-role` | Control plane do EKS |
| `eks-nodegroup-role` | Nodes EC2 (Node Group inicial + nodes do Karpenter) |

> As roles são referenciadas via variável nos módulos. Copie os arquivos `.tfvars.example` para `.tfvars` e ajuste os ARNs conforme sua conta.

---

## Deploy

A infra é dividida em dois módulos Terraform aplicados em sequência.

### Passo 1 — Cluster EKS

```bash
cd terraform/01-eks

# Copie e ajuste as variáveis
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com os ARNs das suas roles e a região desejada

terraform init
terraform plan
terraform apply   # ~15 a 20 minutos
```

Ao final, anote o output `kubeconfig_command` e configure o kubectl:

```bash
aws eks update-kubeconfig --region <sua-regiao> --name <nome-do-cluster>
kubectl get nodes
```

### Passo 2 — Karpenter

```bash
cd terraform/02-karpenter

cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com cluster_name, node_instance_profile e karpenter_node_iam_role_arn

terraform init
terraform plan
terraform apply   # ~3 a 5 minutos

# Verifique a instalação
kubectl get pods -n karpenter
kubectl get nodepool
kubectl get ec2nodeclass
```

---

## Testando o escalonamento

Aplique um dos deployments de exemplo:

```bash
kubectl apply -f deployment/karpenter/api-ecommerce.yaml
```

Acompanhe o Karpenter provisionar novos nodes:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
kubectl get nodes -w
```

Fluxo esperado:

```
1. Pod fica Pending por falta de capacidade
2. Karpenter detecta o pod Pending
3. Karpenter seleciona o tipo de instância ideal para o NodePool alvo
4. Nova instância EC2 é provisionada em ~30 segundos
5. Node entra no cluster e pod é agendado
```

Remova o teste:

```bash
kubectl delete -f deployment/karpenter/api-ecommerce.yaml
```

O Karpenter consolida os nodes ociosos automaticamente (configurado em `consolidateAfter`).

---

## Destruir o ambiente

```bash
# Remova primeiro os recursos do Karpenter
cd terraform/02-karpenter && terraform destroy

# Depois destrua o cluster e a VPC
cd terraform/01-eks && terraform destroy
```

> **Atenção:** Delete manualmente quaisquer Load Balancers ou volumes EBS criados por workloads antes de rodar o `destroy`, pois eles impedem a remoção da VPC.

---

## Verificar a versão mais recente do Karpenter

```bash
aws ecr-public describe-image-tags \
  --repository-name karpenter/karpenter \
  --region us-east-1 \
  --query 'imageTagDetails[*].imageTag' \
  --output text | tr '\t' '\n' | grep '^1\.' | sort -V | tail -5
```

---

## Referências

- [Karpenter — Documentação oficial](https://karpenter.sh/docs/)
- [EKS Best Practices — Karpenter](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [terraform-aws-modules/eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
