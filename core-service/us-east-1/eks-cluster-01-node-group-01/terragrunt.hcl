include {
  path = find_in_parent_folders("global.hcl")
  expose = true
}

locals {
  module_name     = "eks-node-group"
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
  paths = ["../vpc-core", "../security-groups", "../eks-cluster-01"]
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

dependency "eks_cluster" {
  config_path = "../eks-cluster-01"
  mock_outputs = {
    cluster_name = "mycluster"
  }
}

inputs = {
  deployment                  = local.deployment
  region                      = local.region
  account_id                  = local.deployment.account_id
  node_group_name             = "MyNodeGroup"
  scaling_config_desired_size = 3
  scaling_config_max_size     = 3
  scaling_config_min_size     = 1
  eks_ng_secgrp_name          = "eks-node-group"
  vpc_core_outputs            = dependency.vpc_core.outputs
  security_groups_outputs     = dependency.security_groups.outputs
  eks_cluster_outputs         = dependency.eks_cluster.outputs
  deployment_tags = {
    env = local.deployment.environment
  }
}
