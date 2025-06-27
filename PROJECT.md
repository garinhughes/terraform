# Project Proposal: Secure Azure-Based Django Platform

## Overview
This project provisions a secure, production-grade Django web application platform on Azure using Infrastructure as Code (Terraform). The architecture leverages managed Azure services to maximize security, scalability, and operational efficiency, with a strong focus on DevSecOps practices throughout the lifecycle.

## Main Services
| Service                        | Managed? | Purpose                                                      |
|------------------------------- |----------|--------------------------------------------------------------|
| Azure Kubernetes Service (AKS) | Yes      | Managed Kubernetes for app hosting and scaling               |
| Azure Container Registry (ACR) | Yes      | Secure container image storage and scanning                  |
| Azure PostgreSQL Flexible      | Yes      | Managed PostgreSQL database with private networking          |
| Azure Key Vault                | Yes      | Centralized secrets management and access control            |
| Azure Storage Account          | Yes      | Static/media file storage for Django (via Azure Blob)        |
| Azure DNS                      | Yes      | Domain and DNS management                                    |
| Azure Active Directory (AAD)   | Yes      | Authentication and RBAC for users and service principals     |
| Azure Private DNS              | Yes      | Internal DNS for private endpoints (e.g., PostgreSQL)        |
| Azure Network Security Groups  | Yes      | Fine-grained network access control                          |
| Helm (cert-manager, nginx)     | -        | Automated TLS and secure ingress for Kubernetes. See note on Ingress Security below.              |

## Security-First Approach
### 1. Image and Application Scanning
- **Container Image Scanning:**
  - All images are built and pushed to Azure Container Registry (ACR), which supports built-in vulnerability scanning.
  - CI/CD pipelines should enforce image scanning before deployment to AKS.
- **Application Security:**
  - Use SAST/DAST tools (e.g., GitHub Advanced Security, Trivy, or Snyk) in CI/CD to scan Django code and dependencies for vulnerabilities before production deployment.

### 2. Secrets Management
- **Azure Key Vault** is used for all sensitive values (DB passwords, API keys, etc.).
- No secrets are hardcoded or stored in code or environment files.
- Access to Key Vault is controlled via Azure AD and RBAC, with least-privilege policies.
- Service Principals and Managed Identities are used for automated access.

### 3. Network Security
- **Private Networking:**
  - PostgreSQL and other critical services are only accessible via private subnets and peered VNets.
  - No public access to databases or internal APIs.
- **Network Security Groups (NSGs):**
  - Restrict inbound/outbound traffic to only what is required (e.g., AKS to DB on 5432).
- **Ingress Security:**
  - NGINX Ingress Controller is deployed with Web Application Firewall (WAF) and ModSecurity enabled.
  - Automated TLS via cert-manager and DNS-validated certificates.
  - Note: These can both be replaced by Azure Frontdoor when appropriate.

### 4. Authentication and Authorization
- **Django Authentication:**
  - Uses Azure AD OAuth2 for user authentication (multi-tenant, with RBAC).
  - Custom user model supports granular permissions and roles.
- **Permissions:**
  - Django permissions and groups are enforced for all sensitive operations (e.g. django-guardian).
  - Admin and privileged actions are protected by both Django and Azure RBAC.

### 5. Secure Storage and Data Handling
- **Static and Media Files:**
  - Served from Azure Blob Storage with private access and signed URLs.
- **Database:**
  - Encrypted at rest and in transit.
  - Automated backups and point-in-time restore enabled.

### 6. CI/CD and DevSecOps
- **Pipeline Security:**
  - All deployments are automated via CI/CD (e.g., GitHub Actions, Azure DevOps).
  - Secrets are injected at runtime from Key Vault.
  - Enforce code review, static analysis, and image scanning as pipeline gates.
- **Audit and Monitoring:**
  - Enable Azure Monitor and logging for all resources.
  - Regular access reviews and security audits.

### 7. Sensitive Data Controls & Auditing
- **Data Classification & Access Control:**
  - All personal and financial data is classified and access is restricted to only authorized users/groups using Django permissions and Azure RBAC.
  - Fine-grained object-level permissions (e.g., django-guardian) are enforced for sensitive models (quotes, invoices, etc.).
- **Data Separation:**
  - Where feasible, sensitive data is stored in logically or physically separated databases or schemas, with separate credentials and access policies.
  - Application code and infrastructure are designed to minimize data exposure between components (e.g., separate storage accounts for static/media vs. financial documents).
- **Auditing & Monitoring:**
  - All access to sensitive data is logged (both at the Django application level and via Azure Monitor/Log Analytics).
  - Regular review of access logs and audit trails to detect unauthorized or suspicious activity.
  - Database-level auditing is enabled for all financial and personal data tables.
- **Data Protection:**
  - Sensitive fields are encrypted at rest using field-level encryption in Django and Azure-managed keys.
  - All data in transit is protected with TLS (end-to-end, including internal service communication).
- **Data Retention & Compliance:**
  - Data retention policies are enforced for personal and financial data, with automated purging where required.
  - Compliance with relevant standards (e.g., GDPR, PCI DSS) is reviewed and documented.
- **Incident Response:**
  - Automated alerts for access anomalies or policy violations.
  - Documented incident response plan for data breaches or suspicious activity.

## Summary
This project delivers a robust, secure, and scalable Django platform on Azure, leveraging managed services and best practices for security at every layer. All infrastructure is defined as code, enabling repeatable, auditable, and automated deployments. Security is embedded from development through to production, with continuous monitoring and improvement.
