locals {
  authorized_account = run_cmd("python", "-c", "import os,sys; os.chdir('${get_parent_terragrunt_dir()}');from utilities.helpers import getAWSAuthorizedAccountIds;getAWSAuthorizedAccountIds()")
  #deployment_service_account_id               = run_cmd("python", "-c", "import os,sys; os.chdir('${get_parent_terragrunt_dir()}');from utilities.helpers import getAWSAuthorizedAccountIds;getAWSAuthorizedAccountIds()")
  deployment_configuration         = jsondecode(file("${get_parent_terragrunt_dir()}/deployments.json"))
  deployment_service_account_id    = local.deployment_configuration["deploymentService"]["account_id"]
  deployment_service_iam_role_name = local.deployment_configuration["deploymentService"]["AWSProfileName"]
  aws_local_profile                = local.deployment_configuration["deploymentService"]["AWSProfileName"]
  tf_state_region                  = local.deployment_configuration["deploymentService"]["terraformStateRegion"]
  tf_state_bucket                  = "terraform-deployment-state-files-${local.deployment_service_account_id}"


  domain_names = {
    private = {
      cla18 : ""
      csv17 : ""
      prod0 : "mylab.local"
      dev0 : "dev.mylab.local"
    },
    public = {
      prod0 : "mylab.com"
    }
  }

}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = local.tf_state_bucket
    dynamodb_table = "terraform-remote-state-locks"
    key            = format("${path_relative_to_include()}/terraform.tfstate")
    region         = local.tf_state_region
    profile        = local.aws_local_profile
  }
}

inputs = {
  global_tags = {
    terraformed = "true"
  }
  default_vpc_name                 = "main"
  aws_allowed_account_ids          = local.authorized_account
  aws_local_profile                = local.aws_local_profile
  tf_state_region                  = local.tf_state_region
  deployment_service_iam_role_name = local.deployment_service_iam_role_name
  domain_names                     = local.domain_names
  tf_state_bucket                  = local.tf_state_bucket

  common_endpoint_list_interface = [
    {
      name         = "Cloudwatch Logs"
      service_name = "logs"
      sg_name      = "My Default"
      #availability_zone = local.global_values.endpoint_default_az
    },
    {
      name         = "Systems Manager Messages Endpoint"
      service_name = "ssmmessages"
      sg_name      = "My Default"
      #availability_zone = local.global_values.endpoint_default_az
    },
    {
      name         = "EC2 Messages Endpoint"
      service_name = "ec2messages"
      sg_name      = "My Default"
    },
    {
      name         = "Systems Manager Endpoint"
      service_name = "ssm"
      sg_name      = "My Default"
    }
  ]

  common_endpoint_list_gateway = [
    ### S3 - The endpoint for AWS S3
    {
      name         = "S3 Endpoint"
      service_name = "s3"
      sg_name      = "default"
    },
  ]

  #https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-profile.html
  common_iam_instance_policies = {
    SSM = { policy = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" },
    #CloudWatch         = { policy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" },
    #Directory_services = { policy = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess" },
    #Patching_S3        = { policy = "arn:aws:iam::${local.world.account_id}:policy/CCT_s3_patching_execution_log_upload" }
  }
}

generate "global" {
  path      = "global.tf"
  if_exists = "overwrite"
  contents  = <<EOF

variable "default_vpc_name" {
  type        = string
  description = "Default VPC name"
}

variable "global_tags" {
  type        = map(string)
  description = "Detault tags for all objects that accept tags"
}

variable "aws_allowed_account_ids" {
  type        = string
  description = "The AWS account ID of the environment."
}

variable "aws_local_profile" {
  type        = string
  description = "The AWS profile name as set in the shared credentials file."
}

variable "domain_names" {
  type        = map(map(string))
  description = "Domain names per environment/deployment"
}

variable "deployment_service_iam_role_name" {
  type        = string
  description = "Deployment service IAM role name"
}

variable "tf_state_bucket" {
  type        = string
  description = "S3 bucket for storing terraform state files"
}

variable "common_iam_instance_policies" {
  type        = map
  description = "List of IAM Policies for all IAM Instance Roles"
}
EOF
}