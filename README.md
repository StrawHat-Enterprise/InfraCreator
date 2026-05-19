# InfraCreator - AKS Infrastructure

This repository contains Terraform configurations for deploying AKS clusters and supporting infrastructure to Azure. It uses modules from the [Azure-Catalog](../Azure-Catalog) repository.

**Supports IssueOps** - Deploy infrastructure by opening an issue and commenting commands!

## Repository Structure

```
InfraCreator/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── aks-deployment.yml      # IssueOps template
│   └── workflows/
│       ├── issueops-set-backend.yml    # /set-aks-backend workflow
│       └── issueops-build-aks.yml      # /build-aks-<env> workflow
│
├── AKS/
│   ├── backend/                    # Terraform state backend infrastructure
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── terraform.tfvars.example
│   │
│   └── infra/                      # Main AKS infrastructure
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── backend.tf
│       └── environments/           # Environment-specific configurations
│           ├── dev-linux.tfvars           # Dev with Linux-only nodes
│           └── prod-linux-windows.tfvars  # Prod with Linux + Windows nodes
│
└── README.md
```

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** >= 1.5.0
3. **Azure Subscription** with appropriate permissions
4. Both **InfraCreator** and **Azure-Catalog** repositories cloned side-by-side:
   ```
   workspace/
   ├── InfraCreator/
   └── Azure-Catalog/
   ```

---

## 🚀 IssueOps Deployment (Recommended)

Deploy AKS infrastructure using GitHub Issues - no local setup required!

### Step 1: Create a Deployment Issue

1. Go to **Issues** → **New Issue**
2. Select the **AKS Infrastructure Deployment** template
3. Fill in the configuration form (organization prefix, region, etc.)
4. Submit the issue

### Step 2: Initialize Backend

Comment on the issue:
```
/set-aks-backend
```

This creates the storage account for Terraform state files. Wait for the success comment.

### Step 3: Deploy AKS

Comment on the issue:
```
/build-aks-dev
```
or
```
/build-aks-prod
```

### All IssueOps Commands

| Command | Description |
|---------|-------------|
| `/set-aks-backend` | Initialize Terraform backend (storage account) |
| `/build-aks-dev` | Deploy development AKS cluster |
| `/build-aks-prod` | Deploy production AKS cluster |
| `/build-aks-community` | Alias for `/build-aks-dev` |
| `/build-aks-gh-supported` | Alias for `/build-aks-prod` |
| `/plan-aks-dev` | Show plan for development changes |
| `/plan-aks-prod` | Show plan for production changes |
| `/plan-aks-community` | Alias for `/plan-aks-dev` |
| `/plan-aks-gh-supported` | Alias for `/plan-aks-prod` |
| `/destroy-aks-dev` | Destroy development infrastructure |
| `/destroy-aks-prod` | Destroy production infrastructure |

### Two-cluster ARC topology

- Cluster A (`dev`) uses community ARC flavor:
  - `/build-aks-community`
  - `/bootstrap-flux-dev`
  - `/deploy-runners env=dev flavor=community types=dind`
- Cluster B (`prod`) uses GitHub-supported ARC flavor with all required types:
  - `/build-aks-gh-supported`
  - `/bootstrap-flux-prod`
  - `/deploy-runners env=prod flavor=gh-supported types=dind,kubernetes-pvc,kubernetes-novolume`

### Required GitHub Secrets

Configure these secrets in your repository settings:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Azure Service Principal client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `WINDOWS_ADMIN_PASSWORD` | Password for Windows node pools (prod only) |

> **Note:** The workflows use OIDC authentication. Configure a federated credential for your service principal.

---

## Quick Start (Manual)

### Step 1: Deploy Backend Infrastructure (One-time setup)

The backend infrastructure creates a storage account for Terraform state files.

```bash
cd InfraCreator/AKS/backend

# Copy and customize the example tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and apply
terraform init
terraform plan
terraform apply

# Note the outputs for configuring the main infrastructure
terraform output backend_config
```

### Step 2: Deploy AKS Infrastructure

```bash
cd InfraCreator/AKS/infra

# Initialize with backend configuration
terraform init \
  -backend-config="resource_group_name=<from-backend-output>" \
  -backend-config="storage_account_name=<from-backend-output>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=aks-dev.tfstate"

# Plan with environment-specific variables
terraform plan -var-file="environments/dev-linux.tfvars"

# Apply
terraform apply -var-file="environments/dev-linux.tfvars"
```

## Environment Configurations

### Development (Linux Only)

File: `AKS/infra/environments/dev-linux.tfvars`

- **System Node Pool**: 1-3 nodes, Standard_D2s_v3
- **User Node Pool**: 1-5 Linux nodes for workloads
- **Spot Pool**: 0-3 spot instances for batch/test workloads
- **SKU**: Free tier
- Cost-optimized for development workflows

```bash
terraform apply -var-file="environments/dev-linux.tfvars"
```

### Production (Linux + Windows)

File: `AKS/infra/environments/prod-linux-windows.tfvars`

- **System Node Pool**: 3-5 nodes, Standard_D4s_v3
- **Linux Apps Pool**: 3-20 nodes for general workloads
- **Linux Memory Pool**: 0-10 memory-optimized nodes
- **Windows Apps Pool**: 2-10 Windows 2022 nodes for .NET
- **Windows Legacy Pool**: 0-5 Windows 2019 nodes for legacy .NET
- **Spot Pool**: 0-10 spot instances for batch workloads
- **SKU**: Standard tier (SLA)
- Zone-redundant, production-ready

```bash
# Set Windows password via environment variable
export TF_VAR_windows_admin_password="YourSecurePassword123!"

terraform apply -var-file="environments/prod-linux-windows.tfvars"
```

## CI/CD Pipeline Integration

Both repositories should be cloned in the pipeline workspace:

### Azure DevOps Example

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Plan
    jobs:
      - job: TerraformPlan
        steps:
          # Clone Azure-Catalog (modules)
          - checkout: self
          - checkout: git://YourProject/Azure-Catalog@main

          - task: TerraformInstaller@0
            inputs:
              terraformVersion: '1.5.0'

          - task: TerraformTaskV4@4
            displayName: 'Terraform Init'
            inputs:
              provider: 'azurerm'
              command: 'init'
              workingDirectory: '$(System.DefaultWorkingDirectory)/InfraCreator/AKS/infra'
              backendServiceArm: 'Azure-Service-Connection'
              backendAzureRmResourceGroupName: 'rg-tfstate'
              backendAzureRmStorageAccountName: 'sttfstate'
              backendAzureRmContainerName: 'tfstate'
              backendAzureRmKey: 'aks-$(Environment).tfstate'

          - task: TerraformTaskV4@4
            displayName: 'Terraform Plan'
            inputs:
              provider: 'azurerm'
              command: 'plan'
              workingDirectory: '$(System.DefaultWorkingDirectory)/InfraCreator/AKS/infra'
              commandOptions: '-var-file="environments/$(Environment).tfvars"'
              environmentServiceNameAzureRM: 'Azure-Service-Connection'

  - stage: Apply
    dependsOn: Plan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: TerraformApply
        environment: 'production'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - checkout: git://YourProject/Azure-Catalog@main
                
                - task: TerraformTaskV4@4
                  displayName: 'Terraform Apply'
                  inputs:
                    provider: 'azurerm'
                    command: 'apply'
                    workingDirectory: '$(System.DefaultWorkingDirectory)/InfraCreator/AKS/infra'
                    commandOptions: '-var-file="environments/$(Environment).tfvars" -auto-approve'
                    environmentServiceNameAzureRM: 'Azure-Service-Connection'
```

### GitHub Actions Example

```yaml
name: Terraform AKS Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  TF_VAR_windows_admin_password: ${{ secrets.WINDOWS_ADMIN_PASSWORD }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout InfraCreator
        uses: actions/checkout@v4
        with:
          path: InfraCreator

      - name: Checkout Azure-Catalog
        uses: actions/checkout@v4
        with:
          repository: your-org/Azure-Catalog
          path: Azure-Catalog

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        working-directory: InfraCreator/AKS/infra
        run: |
          terraform init \
            -backend-config="resource_group_name=${{ vars.TF_STATE_RG }}" \
            -backend-config="storage_account_name=${{ vars.TF_STATE_SA }}" \
            -backend-config="container_name=tfstate" \
            -backend-config="key=aks-${{ github.event.inputs.environment || 'dev' }}.tfstate"

      - name: Terraform Plan
        working-directory: InfraCreator/AKS/infra
        run: terraform plan -var-file="environments/${{ github.event.inputs.environment || 'dev' }}-linux.tfvars"

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        working-directory: InfraCreator/AKS/infra
        run: terraform apply -var-file="environments/${{ github.event.inputs.environment || 'dev' }}-linux.tfvars" -auto-approve
```

## Resources Created

The infrastructure creates:

| Resource | Description |
|----------|-------------|
| Resource Group | Container for all resources |
| Virtual Network | Network with subnets for AKS, private endpoints |
| NAT Gateway | Outbound connectivity for AKS nodes |
| AKS Cluster | Kubernetes cluster with configured node pools |
| Azure Container Registry | Container image storage |
| Key Vault | Secret and certificate management |
| Storage Account | Blob storage for backups and data |
| Log Analytics Workspace | Monitoring and logging |
| Managed Identities | AKS cluster and kubelet identities |

## Connecting to the Cluster

After deployment, connect to the cluster:

```bash
# Get credentials
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>

# Verify connection
kubectl get nodes
```

## Windows Node Pool Usage

For workloads on Windows nodes, use node selectors:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: windows-app
spec:
  selector:
    matchLabels:
      app: windows-app
  template:
    metadata:
      labels:
        app: windows-app
    spec:
      nodeSelector:
        kubernetes.io/os: windows
      tolerations:
        - key: "os"
          operator: "Equal"
          value: "windows"
          effect: "NoSchedule"
      containers:
        - name: app
          image: mcr.microsoft.com/windows/servercore:ltsc2022
```

## Customization

### Adding New Environments

1. Copy an existing tfvars file:
   ```bash
   cp AKS/infra/environments/dev-linux.tfvars AKS/infra/environments/staging-linux.tfvars
   ```

2. Customize the values for your environment

3. Deploy:
   ```bash
   terraform apply -var-file="environments/staging-linux.tfvars"
   ```

### Adding Node Pools

Edit the `additional_node_pools` variable in your tfvars file:

```hcl
additional_node_pools = {
  # Add a GPU pool
  gpu = {
    vm_size     = "Standard_NC6s_v3"
    os_type     = "Linux"
    os_sku      = "Ubuntu"
    min_count   = 0
    max_count   = 4
    node_labels = {
      "hardware" = "gpu"
    }
    node_taints = ["nvidia.com/gpu=present:NoSchedule"]
  }
}
```

## License

MIT