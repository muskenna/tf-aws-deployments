include {
  path   = find_in_parent_folders("global.hcl")
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
        { rule_desc = "Node to node all ports/protocols", direction = "ingress", from_port = "0", to_port = "0", protocol = "-1", cidr_blocks = [], source_security_group_name = "", self = true },
        { rule_desc = "Node all egress", direction = "egress", from_port = "0", to_port = "0", protocol = "-1", cidr_blocks = [], source_security_group_name = "", self = true },
        { rule_desc = "Egress all HTTPS to internet", direction = "egress", from_port = "80", to_port = "80", protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], source_security_group_name = "", self = false },
        { rule_desc = "Egress NTP/TCP to internet TCP", direction = "egress", from_port = "123", to_port = "123", protocol = "tcp", cidr_blocks = ["169.254.169.123/32"], source_security_group_name = "", self = false },
        { rule_desc = "Egress NTP/TCP to internet UDP", direction = "egress", from_port = "123", to_port = "123", protocol = "udp", cidr_blocks = ["169.254.169.123/32"], source_security_group_name = "", self = false },

        #{ rule_desc = "Node groups to cluster API", direction = "ingress", from_port = "80", to_port = "80", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Cluster API to node groups", direction = "egress", from_port = "80", to_port = "80", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Cluster API to node kubelets", direction = "egress", from_port = "10250", to_port = "10250", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Node to node CoreDNS TCP Egress", direction = "egress", from_port = "53", to_port = "53", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Node to node CoreDNS TCP Ingress", direction = "ingress", from_port = "53", to_port = "53", protocol = "tcp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Node to node CoreDNS UDP Egress", direction = "egress", from_port = "53", to_port = "53", protocol = "udp", cidr_blocks = [], source_security_group_name = "", self = true },
        #{ rule_desc = "Node to node CoreDNS UDP Ingress", direction = "ingress", from_port = "53", to_port = "53", protocol = "udp", cidr_blocks = [], source_security_group_name = "", self = true }

      ]
    },
    {
      name = "eks-node-groups-remote-access", group_desc = "EKS Node Groups SSH Remote Access", rules = [
        { rule_desc = "Allow remote SSH access", direction = "ingress", from_port = "22", to_port = "22", protocol = "tcp", cidr_blocks = ["172.16.0.0/16"], source_security_group_name = "", self = false }
      ]
    }
  ]
}
