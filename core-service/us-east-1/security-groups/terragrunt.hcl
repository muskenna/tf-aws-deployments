include {
  path = find_in_parent_folders("global.hcl")
  expose = true
}

locals {
  module_name     = "security-groups"
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
  paths = ["../vpc-core"]
}

dependency "vpc_core" {
  config_path = "../vpc-core"
  mock_outputs = {
    vpc_id = "vpc-123456789987"
  }
}

inputs = {
  deployment     = local.deployment
  region         = local.region
  account_id     = local.deployment.account_id
  vpc_cidr_block = local.deployment.vpc_cidr_block
  vpc_outputs    = dependency.vpc_core.outputs
  deployment_tags = {
    env = local.deployment.environment
  }

  #Check %REPO_ROOT%\libray\security-groups\README.md for notes
  security_groups = [
    {
      name = "eks-cluster", group_desc = "EKS Cluster", rules = [
        { rule_desc = "Node groups to cluster API", direction = "ingress", from_port = "80", to_port = "80", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        { rule_desc = "Cluster API to node groups", direction = "egress", from_port = "80", to_port = "80", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        { rule_desc = "Cluster API to node kubelets", direction = "egress", from_port = "10250", to_port = "10250", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true }
      ]
    }
  ]
}
