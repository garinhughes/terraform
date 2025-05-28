# terraform

This Terraform configuration provisions a set of Azure resources for a Kubernetes-based application deployment. There's a lot configured here that ideally needs separating into Terraform modules. If testing, my advice would be to break this configuration down into chunks, despite being in a logical creation order.

## Main Resources

- **Resource Group**: Central resource group for all resources.
- **Virtual Network (VNet)**: Main VNet for the environment, with subnets for PostgreSQL and AKS.
- **Subnets**: Dedicated subnet for PostgreSQL Flexible Server with delegation.
- **Storage Account & Container**: For general storage needs.
- **Key Vault**: Stores secrets such as the PostgreSQL admin password, with access policies for users and service principals.
- **Azure AD Application & Service Principal**: For secure access to Key Vault.
- **Private DNS Zone**: For PostgreSQL Flexible Server private endpoint resolution.
- **PostgreSQL Flexible Server**: Managed PostgreSQL instance, deployed in a private subnet with private DNS.
- **Container Registry (ACR)**: For storing Docker images used by AKS.
- **AKS Cluster**: Azure Kubernetes Service cluster, configured with autoscaling and system-assigned identity.
- **Role Assignment**: Grants AKS permission to pull images from ACR.
- **Virtual Network Peerings**: Bi-directional peering between the main VNet and the AKS VNet for network connectivity.
- **Helm Releases**:
  - **NGINX Ingress Controller**: Deployed via Helm in its own namespace, exposes services via LoadBalancer.
  - **cert-manager**: Deployed via Helm for automated TLS certificate management.
- **DNS Zone & Records**: Public DNS zone for ghdev.uk, with A records for root and www pointing to the NGINX Ingress external IP.

## Key Connections

- **AKS <-> ACR**: AKS is granted the AcrPull role to pull images from the Azure Container Registry.
- **AKS <-> PostgreSQL**: AKS accesses PostgreSQL via private networking and DNS, with secrets managed in Key Vault.
- **AKS <-> VNet Peering**: The main VNet and the AKS VNet are peered for full network connectivity.
- **AKS <-> Ingress**: NGINX Ingress Controller is deployed in AKS and exposed via a public LoadBalancer IP, which is used for DNS records.
- **cert-manager**: Manages TLS certificates for Ingress resources using Let's Encrypt.

## Providers

- **azurerm**: Manages all Azure resources.
- **azuread**: Manages Azure Active Directory resources.
- **kubernetes**: Manages Kubernetes resources within AKS.
- **helm**: Deploys Helm charts (NGINX Ingress, cert-manager) into AKS.

## Remote State Backend

This project uses an Azure Storage Account as a remote backend for storing the Terraform state file. This ensures state consistency and enables team collaboration. The backend is configured in `providers.tf`, and uses the following Azure resources:

- **Storage Account**: Stores the state file securely in a blob container.
- **Storage Container**: Dedicated container (e.g., `ghdevcontainer`) for Terraform state blobs.
- **State Locking**: Azure Storage provides state locking to prevent concurrent modifications.

To use the remote backend, ensure the storage account and container are created (as defined in `main.tf`), then configure your backend block, for example:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "<resource-group-name>"
    storage_account_name = "<storage-account-name>"
    container_name       = "<container-name>"
    key                  = "terraform.tfstate"
  }
}
```

Replace the placeholders with your actual resource names. After configuration, run `terraform init` to initialize the backend. If you've already done this locally before configuring the backend, you may need to migrate the state with `terraform init -migrate-state`.

## Usage

1. Run `terraform init -upgrade` to initialize providers and the backend.
2. Run `terraform plan -out main.tfplan` to prepare the deployment.
3. Run `terraform apply main.tfplan` to provision all resources.
4. After deployment, your application will be accessible via the DNS records configured for ghdev.uk and www.ghdev.uk, routed through the NGINX Ingress Controller. You'll need to deploy these separately.
