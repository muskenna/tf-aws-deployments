## ArgoCD Configuration ##

Pre-Req

    choco install kubernetes-helm
    choco install k9s https://github.com/derailed/k9s
    choco install kubectx
    choco install kubernetes-cli
    choco install argocd-cli
    https://github.com/argoproj/argo-rollouts/releases/ >  Assets > kubectl-argo-rollouts-windows-amd64
    


kubectx -d arn:aws:eks:us-east-1:752747581373:cluster/Cluster-01 (kubectx.exe -d (kubectx.exe))
aws eks update-kubeconfig --name Cluster-01 --profile MyDeploymentService --region us-west-2 --role-arn arn:aws:iam::752747581373:role/MyDeploymentService
kubectl create namespace argocd
kubectl create namespace argo-rollouts
kubectl get namespaces
kubectl apply -f "https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.8/manifests/ha/install.yaml" -n argocd
kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml -n argo-rollouts

Windows
    $pwdhash=Invoke-Expression 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"'; $argocd_pwd=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pwdhash));$argocd_pwd
Linux
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

kubectl port-forward service/argocd-server 8443:443 -n argocd
argocd add cluster... ??
argocd login localhost:8443 --insecure --username admin --password $argocd_pwd
argocd app create apps --dest-namespace argocd --dest-server https://kubernetes.default.svc --repo https://github.com/argoproj/argocd-example-apps.git --path apps

*Resource: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/*

Demo App
argocd app delete guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace argocd


Argo Rollouts

https://argoproj.github.io/argo-rollouts/getting-started/
