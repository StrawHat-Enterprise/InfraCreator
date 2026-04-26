# =============================================================================
# AKS Infrastructure - Outputs
# =============================================================================

# =============================================================================
# Resource Group Outputs
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = module.resource_group.id
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = module.resource_group.location
}

# =============================================================================
# AKS Cluster Outputs
# =============================================================================

output "aks_cluster_id" {
  description = "The ID of the AKS cluster"
  value       = module.aks.id
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.name
}

output "aks_cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = module.aks.fqdn
}

output "aks_cluster_private_fqdn" {
  description = "The private FQDN of the AKS cluster (if private)"
  value       = module.aks.private_fqdn
}

output "aks_kubernetes_version" {
  description = "The Kubernetes version of the cluster"
  value       = module.aks.kubernetes_version
}

output "aks_oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

# =============================================================================
# Identity Outputs
# =============================================================================

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS cluster identity"
  value       = module.aks_identity.principal_id
}

output "aks_identity_client_id" {
  description = "Client ID of the AKS cluster identity"
  value       = module.aks_identity.client_id
}

output "kubelet_identity_principal_id" {
  description = "Principal ID of the kubelet identity"
  value       = module.kubelet_identity.principal_id
}

output "kubelet_identity_client_id" {
  description = "Client ID of the kubelet identity"
  value       = module.kubelet_identity.client_id
}

# =============================================================================
# Network Outputs
# =============================================================================

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.virtual_network.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.virtual_network.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = module.virtual_network.subnet_ids
}

# =============================================================================
# Container Registry Outputs
# =============================================================================

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.container_registry.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = module.container_registry.name
}

output "acr_login_server" {
  description = "Login server URL for the ACR"
  value       = module.container_registry.login_server
}

# =============================================================================
# Key Vault Outputs
# =============================================================================

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.key_vault.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.vault_uri
}

# =============================================================================
# Storage Account Outputs
# =============================================================================

output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = module.storage_account.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage_account.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = module.storage_account.primary_blob_endpoint
}

# =============================================================================
# Log Analytics Outputs
# =============================================================================

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.log_analytics.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.log_analytics.name
}

# =============================================================================
# Connection Commands
# =============================================================================

output "kubectl_config_command" {
  description = "Azure CLI command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.name}"
}
