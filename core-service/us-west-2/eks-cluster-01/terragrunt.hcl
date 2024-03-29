include {
  path   = find_in_parent_folders("global.hcl")
  expose = true
}

locals {
  module_name     = "eks-cluster"
  region          = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-2])")
  deployment_name = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-3])")
  git_source      = include.locals.deployment_configuration["git_source"]
  local_dev_env   = include.locals.deployment_configuration["local_dev_env"]
  deployment      = include.locals.deployment_configuration["deployments"][local.deployment_name]["regions"][local.region]
}

terraform {
  source = local.local_dev_env ? format("%s/tf-aws-library//${local.module_name}", "${get_parent_terragrunt_dir()}") : "${local.git_source}//${local.module_name}"
}
dependencies {
  paths = ["../vpc-core", "../security-groups"]
}

dependency "vpc_core" {
  config_path = "../vpc-core"
  mock_outputs = {
    vpc_name = "vpc0"
    vpc_id   = "vpc-111111111111"
    subnet_ids = {
      "vpc0-private-primary"   = "subnet-11111111111"
      "vpc0-private-secondary" = "subnet-222222222222"
    }
  }
}

dependency "security_groups" {
  config_path = "../security-groups"
  mock_outputs = {
    security_group_ids = {
      "eks-cluster" = "sg-11111111111"
    }
  }
}


inputs = {
  deployment                      = local.deployment
  region                          = local.region
  account_id                      = local.deployment.account_id
  cluster_name                    = "Cluster-01"
  kube_version                    = "1.22"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_service_ipv4_cidr       = "10.100.0.0/16"
  cluster_security_group_name     = "eks-cluster"
  vpc_core_outputs                = dependency.vpc_core.outputs
  security_groups_outputs         = dependency.security_groups.outputs
  deployment_tags = {
    env = local.deployment.environment
  }
}
