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



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_endpoint_private_access"></a> [cluster\_endpoint\_private\_access](#input\_cluster\_endpoint\_private\_access) | Indicates whether or not the Amazon EKS private API server endpoint is enabled | `bool` | `false` | no |
| <a name="input_cluster_endpoint_public_access"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | Indicates whether or not the Amazon EKS public API server endpoint is enabled | `bool` | `true` | no |
| <a name="capacity_type"></a> [cluster\_endpoint\_public\_access](#input\_cluster\_endpoint\_public\_access) | When creating a managed node group, you can choose either the On-Demand or Spot capacity type. Amazon EKS deploys a managed node group with an Amazon EC2 Auto Scaling group that either contains only On-Demand or only Amazon EC2 Spot Instances. You can schedule pods for fault tolerant applications to Spot managed node groups, and fault intolerant applications to On-Demand node groups within a single Kubernetes cluster. By default, a managed node group deploys On-Demand Amazon EC2 instances. | `string` | `On-Demand` | no |



## How to install argocd
kubectl apply -n argo-cd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
https://piotrminkowski.com/2022/06/28/manage-kubernetes-cluster-with-terraform-and-argo-cd/
https://www.digitalocean.com/community/tutorials/how-to-deploy-to-kubernetes-using-argo-cd-and-gitops
https://www.youtube.com/watch?v=hIL0E2gLkf8
    https://github.com/argoproj/rollouts-demo
https://www.youtube.com/watch?v=791q82vg5M8
https://www.youtube.com/watch?v=MeU5_k9ssrs
https://www.youtube.com/watch?v=w-E8FzTbN3g
https://www.youtube.com/watch?v=c4v7wGqKcEY&list=PLc2vHWAyCS9RXIAnpRJ6vt7vPnZYLGA7f
https://www.youtube.com/watch?v=0PxQPh3bo3I

https://github.com/argoproj/argo-cd/blob/master/docs/getting_started.md
1 - 
    (optional) - kubectx -d arn:aws:eks:us-east-1:593626306105:cluster/Cluster-01
    aws eks update-kubeconfig --name <cluster_name> --profile <profile> --region <region> --role-arn arn:aws:iam::<accountid>:role/MyDeploymentService
    ex.: aws eks update-kubeconfig --name Cluster-01 --profile MyDeploymentService --region us-east-1 --role-arn arn:aws:iam::104814218041:role/MyDeploymentService   
1.1 kubectl config view -o jsonpath='{.current-context}'
2 - https://argo-cd.readthedocs.io/en/stable/getting_started/ -> Install Argo CD

    kubectl create namespace argocd (terraform already applied it)
    kubectl apply -f "https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.8/manifests/ha/install.yaml" -n argo-cd

3 - kubectl get all -n argo-cd
4 - kubectl port-forward service/argocd-server 8443:443 -n argo-cd
5 - Linux
        kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    Windows
        $pwdhash=Invoke-Expression 'kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"'; $password=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pwdhash));$password

    install argocd cli -> https://argo-cd.readthedocs.io/en/stable/getting_started/ -> Download Argo CD CLI
    choco install argocd-cli
    choco install kubectx

6 - argocd login
    ex1.: 
      - argocd login $(kubectl get service argocd-server -n argo-cd --output=jsonpath='{.status.loadBalancer.ingress[0].hostname}') --username admin --password $(kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo) --insecure
    ex2.:
    - argocd login localhost:8443
7 - argocd cluster add 'arn:aws:eks:us-east-1:593626306105:cluster/Cluster-01'
    https://www.eksworkshop.com/intermediate/290_argocd/configure/

Install Argp-Rollouts
    https://argoproj.github.io/argo-rollouts/getting-started/
    https://argoproj.github.io/argo-rollouts/installation/#controller-installation

1 - kubectl create namespace argo-rollouts
2 - kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
3 - Install "kubectl-argo-rollouts" plugin
    https://github.com/argoproj/argo-rollouts/releases/download/v1.2.2/kubectl-argo-rollouts-windows-amd64
    https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation
4 - Install kustomize
    
    https://kubectl.docs.kubernetes.io/installation/kustomize/chocolatey/
    https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/


4 - Demo and Basic
    https://github.com/argoproj/rollouts-demo
    https://argoproj.github.io/argo-rollouts/getting-started/

