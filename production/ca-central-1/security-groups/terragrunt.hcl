include {
  path = find_in_parent_folders("global.hcl")
}

locals {
  module_name = "security_groups"
  region          = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-2])")
  deployment_name = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-3])")
  all_deployments = jsondecode(file("${get_parent_terragrunt_dir()}/deployments.json"))
  git_source      = local.all_deployments["git_source"]
  local_dev_env   = local.all_deployments["local_dev_env"]
  deployment      = local.all_deployments["deployments"][local.deployment_name]["regions"][local.region]
}

terraform {
  source =  local.local_dev_env == "true" ? format("%s/tf-aws-library//${local.module_name}", "${get_parent_terragrunt_dir()}") : "${local.git_source}//${local.module_name}"
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
      name = "ssh-access", group_desc = "SSH Access", rules = [
        { rule_desc = "SSH Access", direction = "ingress", from_port = "22", to_port = "22", protocol = "SSH", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
    {
      name = "myapp-secure-web-access", group_desc = "MyApp Secure Web Access", rules = [
        { rule_desc = "HTTPS access", direction = "ingress", from_port = "443", to_port = "443", protocol = "HTTPS", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
    {
      name = "postgresql-database-access", group_desc = "PostgreSQL Database Access", rules = [
        { rule_desc = "Default PostgreSQL Port", direction = "ingress", from_port = "5432", to_port = "5432", protocol = "tcp", cidr_blocks = [], source_security_group_name = "myapp-secure-web-access", self = false },
      { rule_desc = "Stateful access", direction = "egress", from_port = "0", to_port = "0", protocol = "all", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false }]
    },
  ]
}
