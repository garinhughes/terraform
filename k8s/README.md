# Overview
This guide explains how to configure an NGINX Ingress Controller and cert-manager via Helm manually. In production, Terraform manages both of these resources (`main.tf`), and you only need to run `kubectl apply -f .` to deploy all Kubernetes manifests.

HTTPS is enabled for two domains with a LetsEncrypt certificate, and the public IP remains accessible for testing (`ingress.yaml`).

## Manual Installation and Testing

### NGINX Ingress Controller

#### Install
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

kubectl create namespace ingress-basic
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-basic \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.progressDeadlineSeconds=600
```

#### Monitor and get External IP
```bash
kubectl get service --namespace ingress-basic nginx-ingress-ingress-nginx-controller --output wide --watch
```

#### Apply Ingress Service
```bash
kubectl apply -f ingress.yaml
```

### Let's Encrypt Certificates

#### Install
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true
```

#### Apply Certificate Resources
```bash
kubectl apply -f letsencrypt.yaml
kubectl apply -f certificate.yaml
```

#### Configure Ingress for TLS
Update `ingress.yaml` to use the SSL/TLS cert, for example:
```yaml
spec:
  tls:
  - hosts:
    - ghdev.uk
    - www.ghdev.uk
    secretName: ghdev-uk-tls
```

### Cleanup
```bash
kubectl delete -f certificate.yaml
kubectl delete -f letsencrypt.yaml
kubectl delete -f ingress.yaml

kubectl delete secret ghdev-uk-tls -n ics
kubectl delete certificate ghdev-uk-tls -n ics

helm uninstall cert-manager --namespace cert-manager
kubectl delete namespace cert-manager

helm uninstall nginx-ingress --namespace ingress-basic
kubectl delete namespace ingress-basic
```

## YAML Files Explained
- **djangoapp.yaml**: Deployment and Cluster IP service for Django app.
- **ingress.yaml**: Defines Ingress rules for routing external traffic to your services, and configures TLS if required.
- **letsencrypt.yaml**: Configures a cert-manager ClusterIssuer or Issuer for Let's Encrypt certificate provisioning.
- **certificate.yaml**: Requests a TLS certificate for your domain(s) using cert-manager and the configured issuer.

## Secrets
Get the storage account key and create a k8s secret
```bash
az storage account keys list --account-name ghdevstorageacc --resource-group ghdev-rg --query "[0].value" -o tsv
kubectl create secret generic azure-storage-secret --from-literal=azurestorageaccountkey=<account-key>
```

## NGINX WAF Rules
The OWASP CSR (core rule set) is already enabled on the NGINX Ingress Controller but you can add custom rules as follows.

1. Add custom rules to [nginx-security-rules.yaml](nginx-security-rules.yaml)
2. Re-apply the ConfigMap
```bash
kubectl apply -f nginx-security-rules.yaml
```
3. Reload the NGINX Ingress Controller
```bash
kubectl rollout restart deployment -n ingress-nginx nginx-ingress-ingress-nginx-controller 
```

Note: this needs more testing. Azure AKS NGINX Ingress Controller denies the use of certain snippet directives for rules so they may need to be placed elsewhere. Enabling them allows flexibility but has security implications (isolation between users and applications).