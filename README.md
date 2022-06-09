# tf-aws-deployments

## Description
This repo contain examples on how to deploy Terraform modules using Terragrunt

## Requirements

1 - Install Terragrunt and Terraform
2 - Install Python 3, and:
    - make it accessible via %PATH% environment variable
    - if your installation only contains the *python3* executable, you need to create an alias to *python*
3 - Rename the template configuration file *deployments.template.json* to *deployments.json* and include your own deployment information
4 - Configure access to the Terraform library
    - the Terraform library must be accessible via SCM using SSH keys
    - here is repo that can be forked -> git@github.com:muskenna/tf-aws-library.git
    - update the configuration file deployments.json ->  "git_source":"git::ssh://git@github.com/username"

## How to deploy
1 - run terragrunt plan
`terragrunt run-all plan -out plan.json --terragrunt-non-interactive --terragrunt-source-update`
2 - read the plan
 `terragrunt run-all show -json`
3 - Apply the changes
`terragrunt run-all apply`