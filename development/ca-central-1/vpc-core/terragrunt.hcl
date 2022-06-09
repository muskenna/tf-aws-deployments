include {
  path = find_in_parent_folders("global.hcl")
}

locals {
  region          = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-2])")
  deployment_name = run_cmd("python", "-c", "import os,sys;np=os.path.normpath(os.getcwd());sys.stdout.write(np.split(os.sep)[-3])")
  all_deployments = jsondecode(file("${get_parent_terragrunt_dir()}/deployments.json"))
  git_source = local.all_deployments["git_source"]
  deployment      = local.all_deployments["deployments"][local.deployment_name]["regions"][local.region]
}

terraform {
  source =  "${local.git_source}/tf-aws-library.git//vpc-core"
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
