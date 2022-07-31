# tf-aws-deployments

## Description
This repo contain examples on how to deploy Terraform modules using Terragrunt

## Requirements

1 - Install Terragrunt and Terraform<br>
2 - Install Python 3, and:<br>
- make it accessible via %PATH% environment variable
- if your installation only contains the *python3* executable, you need to create an alias to *python*<br>

3 - Rename the template configuration file **deployments.template.json** to **deployments.json** and include your own deployment information<br>
4 - Configure access to the Terraform library<br>
- Production<br>
    - the Terraform library must be accessible via SCM using SSH keys<br>
    - here is the repo to be forked -> https://github.com/muskenna/tf-aws-library.git<br>
    - update the configuration file **deployments.json** ->  "git::ssh://git@github.com/%username%/tf-aws-library.git"<br><br>
- Local Development<br>
    - Clone the "tf-aws-library" inside the "tf-aws-deployments" folder. The structure must look like this:
        
        ```
        |--tf-aws-deployments"
        |----tf-aws-library
        |----...
        ```

        It is necessary because the terragrunt file terragrunt.hcl will make a decision if it will use a local or remote source. <br>Here is how it works:<br>
        ```
        terraform {
            source =  local.local_dev_env ? format("%s/tf-aws-library//${local.module_name}", "${get_parent_terragrunt_dir()}") : "${local.git_source}//${local.module_name}"
        }
        ```

5 - Create a deployment service user and deployment IAM roles<br>

To deploy resources to AWS, Terraform must assume the IAM role from each account using the deployment service user.
To create those IAM resource you can execute the script /utilities/setDeploymentServiceAccessControl.py, but first you must have:

- One profile per account, that has permission to create IAM roles, configured in the file **..\.aws\credentials**. These accounts will be used only one for initial setup. Here is an example:
```
[power-user-deployment-account]
aws_access_key_id = ...
aws_secret_access_key = ...
[power-user-development-account]
aws_access_key_id = ...
aws_secret_access_key = ...
```
- the file /utilities/accounts.json updated with your own information.<br>

Here is how the trust relationship is configured by the script
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::xxxxxxxxxxxx:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {}
        }
    ]
}
```
6 - Configure the deployment service  (IAM user) to assume the deployment role (IAM role)
AWS Local profile configuration
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-role-overview

## How to deploy

1 - Run terragrunt plan<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`terragrunt run-all plan`<br>
2 - Apply the changes<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`terragrunt run-all apply`<br>

Using a plan files<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`terragrunt run-all plan -out plan.json`<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`terragrunt run-all show -json`<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`terragrunt run-all apply plan.json`<br>

## Usefull CLI options
* --terragrunt-non-interactive
* --terragrunt-source-update
* --terragrunt-include-dir
* --terragrunt-debug --terragrunt-log-level debug

Source: https://terragrunt.gruntwork.io/docs/reference/cli-options/