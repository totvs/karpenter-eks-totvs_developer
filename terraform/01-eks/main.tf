data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 3)

  vpc_id          = var.create_vpc ? try(module.vpc[0].vpc_id, "") : var.existing_vpc_id
  private_subnets = var.create_vpc ? try(module.vpc[0].private_subnets, []) : var.existing_private_subnet_ids

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
