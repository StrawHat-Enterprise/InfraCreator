# Azure Setup for GitHub Actions OIDC

This document describes the Azure prerequisites required for IssueOps deployment of AKS infrastructure.

## Overview

The workflows use **OpenID Connect (OIDC)** for passwordless authentication between GitHub Actions and Azure. This eliminates the need for storing Azure credentials as secrets.

---

## Azure Resources Created

### App Registration
| Property | Value |
|----------|-------|
| **App Name** | `sp-infracreator-github` |
| **Client ID** | `3efe69a8-785e-4677-b134-39b63653a373` |
| **Object ID** | `c4d257d6-d8fb-4e3f-8330-9f787c1626f8` |

### Federated Credentials

| Name | Subject | Purpose |
|------|---------|---------|
| `github-infracreator-env-dev` | `repo:BkCloudOps/InfraCreator:environment:dev` | Dev deployments |
| `github-infracreator-env-prod` | `repo:BkCloudOps/InfraCreator:environment:prod` | Prod deployments |
| `github-infracreator-branch-main` | `repo:BkCloudOps/InfraCreator:ref:refs/heads/main` | Backend setup |

### Role Assignments

| Role | Scope | Purpose |
|------|-------|---------|
| **Contributor** | Subscription | Create/manage Azure resources |
| **User Access Administrator** | Subscription | Assign RBAC roles to managed identities |

---

## GitHub Configuration

### Repository Secrets

Add these at: `Settings → Secrets and variables → Actions`

| Secret | Value |
|--------|-------|
| `AZURE_CLIENT_ID` | `3efe69a8-785e-4677-b134-39b63653a373` |
| `AZURE_TENANT_ID` | `fa7492f3-e949-4bd8-9963-e88b76996320` |
| `AZURE_SUBSCRIPTION_ID` | `96dd7bbb-5319-4ad7-93a1-ff1de8e90a9b` |

### Environments

Create at: `Settings → Environments`

| Environment | Protection Rules |
|-------------|------------------|
| `dev` | None (optional) |
| `prod` | Required reviewers (recommended) |

---

## Setup Commands

### Create App Registration & Service Principal

```bash
APP_NAME="sp-infracreator-github"
GITHUB_ORG="BkCloudOps"
GITHUB_REPO="InfraCreator"

# Create App Registration
CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)

# Create Service Principal
az ad sp create --id "$CLIENT_ID"
SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)
```

### Create Federated Credentials

```bash
# Dev environment
az ad app federated-credential create --id "$OBJECT_ID" --parameters '{
  "name": "github-infracreator-env-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:BkCloudOps/InfraCreator:environment:dev",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Prod environment
az ad app federated-credential create --id "$OBJECT_ID" --parameters '{
  "name": "github-infracreator-env-prod",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:BkCloudOps/InfraCreator:environment:prod",
  "audiences": ["api://AzureADTokenExchange"]
}'

# Main branch (for backend setup)
az ad app federated-credential create --id "$OBJECT_ID" --parameters '{
  "name": "github-infracreator-branch-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:BkCloudOps/InfraCreator:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### Assign Azure Roles

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Contributor role
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# User Access Administrator role
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

---

## Verification Commands

### Check Federated Credentials

```bash
az ad app federated-credential list --id "$OBJECT_ID" -o table
```

### Check Role Assignments

```bash
az role assignment list --assignee "$SP_OBJECT_ID" --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

### Get Secret Values

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
```

---

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `AADSTS70021: No matching federated identity record found` | Wrong subject claim | Check environment name matches exactly |
| `AuthorizationFailed` | Missing role assignment | Verify Contributor role is assigned |
| `ForbiddenError` | Missing User Access Administrator | Required for AKS managed identity RBAC |

### Useful Links

- [Azure OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Federated Identity Credentials](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
