include {
  path   = find_in_parent_folders("global.hcl")
  expose = true
}

locals {
  module_name     = "vpc-core"
  region          = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-2])")
  deployment_name = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-3])")
  git_source      = include.locals.deployment_configuration["git_source"]
  local_dev_env   = include.locals.deployment_configuration["local_dev_env"]
  deployment      = include.locals.deployment_configuration["deployments"][local.deployment_name]["regions"][local.region]
}

terraform {
  source = local.local_dev_env ? format("%s/tf-aws-library//${local.module_name}", "${get_parent_terragrunt_dir()}") : "${local.git_source}//${local.module_name}"
}

inputs = {
  deployment     = local.deployment
  region         = local.region
  account_id     = local.deployment.account_id
  vpc_cidr_block = local.deployment.vpc_cidr_block
  deployment_tags = {
    env = local.deployment.environment
  }

  subnet_config = [
    { name = "main", az_type = "primary", newbits = "8", netnum = "0", route = "private", nacl = "private" },
    { name = "main", az_type = "secondary", newbits = "8", netnum = "1", route = "private", nacl = "private" },
    { name = "main", az_type = "primary", newbits = "8", netnum = "2", route = "public", nacl = "public", },
    { name = "main", az_type = "secondary", newbits = "8", netnum = "3", route = "public", nacl = "public" }
  ]
}
