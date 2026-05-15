# =============================================================================
# AKS Infrastructure - Main Configuration
# =============================================================================
# This configuration creates a production-ready AKS cluster with all 
# supporting infrastructure using modules from Azure-Catalog.
#
# Usage in CI/CD Pipeline:
#   1. Clone both repos (InfraCreator and Azure-Catalog)
#   2. Run terraform init with backend config
#   3. Run terraform plan/apply with appropriate tfvars
# =============================================================================

# =============================================================================
# Naming Convention Module
# =============================================================================

module "naming" {
  source = "../../../Azure-Catalog/modules/core/naming"

  organization_prefix = var.organization_prefix
  application_name    = var.application_name
  environment         = var.environment
  location            = var.location
  cost_center         = var.cost_center
  owner               = var.owner
}

# =============================================================================
# Resource Group
# =============================================================================

module "resource_group" {
  source = "../../../Azure-Catalog/modules/core/resource-group"

  naming      = module.naming.names
  location    = var.location
  common_tags = module.naming.common_tags

  additional_tags    = var.additional_tags
  enable_delete_lock = var.environment == "production" || var.environment == "prod"
}

# =============================================================================
# Log Analytics Workspace
# =============================================================================

module "log_analytics" {
  source = "../../../Azure-Catalog/modules/monitoring/log-analytics"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  retention_in_days = var.log_analytics_retention_days

  solutions = {
    ContainerInsights = {
      publisher = "Microsoft"
      product   = "OMSGallery/ContainerInsights"
    }
  }
}

# =============================================================================
# Virtual Network
# =============================================================================

module "virtual_network" {
  source = "../../../Azure-Catalog/modules/networking/virtual-network"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  address_space = var.vnet_address_space

  subnets = {
    aks-system = {
      name             = "snet-aks-system"
      address_prefixes = [var.subnet_aks_system]
      service_endpoints = [
        "Microsoft.ContainerRegistry",
        "Microsoft.KeyVault",
        "Microsoft.Storage"
      ]
      nsg_rules = [
        {
          name                       = "AllowHTTPS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
      associate_nat_gateway = var.create_nat_gateway
    }

    aks-user = {
      name             = "snet-aks-user"
      address_prefixes = [var.subnet_aks_user]
      service_endpoints = [
        "Microsoft.ContainerRegistry",
        "Microsoft.KeyVault",
        "Microsoft.Storage"
      ]
      associate_nat_gateway = var.create_nat_gateway
    }

    private-endpoints = {
      name                                      = "snet-private-endpoints"
      address_prefixes                          = [var.subnet_private_endpoints]
      create_nsg                                = false
      private_endpoint_network_policies_enabled = false
    }
  }

  create_nat_gateway = var.create_nat_gateway
}

# =============================================================================
# Managed Identities
# =============================================================================

# AKS Cluster Identity
module "aks_identity" {
  source = "../../../Azure-Catalog/modules/identity/managed-identity"

  naming              = { managed_identity = "${module.naming.names.managed_identity}-aks" }
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags
}

# Kubelet Identity (for pulling from ACR)
module "kubelet_identity" {
  source = "../../../Azure-Catalog/modules/identity/managed-identity"

  naming              = { managed_identity = "${module.naming.names.managed_identity}-kubelet" }
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags
}

# Grant AKS identity "Managed Identity Operator" role on kubelet identity
# Required for AKS to assign kubelet identity to node pools
resource "azurerm_role_assignment" "aks_kubelet_mio" {
  scope                = module.kubelet_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = module.aks_identity.principal_id
}

# =============================================================================
# Azure Container Registry
# =============================================================================

module "container_registry" {
  source = "../../../Azure-Catalog/modules/container/container-registry"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  sku                           = var.acr_sku
  admin_enabled                 = var.acr_admin_enabled
  public_network_access_enabled = true

  # Grant AcrPull to kubelet identity
  acr_pull_identities = {
    kubelet = module.kubelet_identity.principal_id
  }

  diagnostic_settings = {
    log_analytics_workspace_id = module.log_analytics.id
  }
}

# =============================================================================
# Key Vault
# =============================================================================

module "key_vault" {
  source = "../../../Azure-Catalog/modules/storage/key-vault"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  enable_rbac_authorization  = true
  purge_protection_enabled   = var.key_vault_purge_protection
  soft_delete_retention_days = var.key_vault_soft_delete_days

  role_assignments = {
    aks-secrets-user = {
      role_definition_name = "Key Vault Secrets User"
      principal_id         = module.aks_identity.principal_id
    }
  }

  diagnostic_settings = {
    log_analytics_workspace_id = module.log_analytics.id
  }
}

# =============================================================================
# Storage Account
# =============================================================================

module "storage_account" {
  source = "../../../Azure-Catalog/modules/storage/storage-account"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type

  containers = {
    aks-backups = {
      access_type = "private"
    }
    aks-data = {
      access_type = "private"
    }
  }

  role_assignments = {
    aks-blob-contributor = {
      role_definition_name = "Storage Blob Data Contributor"
      principal_id         = module.aks_identity.principal_id
    }
  }
}

# =============================================================================
# AKS Cluster
# =============================================================================

module "aks" {
  source = "../../../Azure-Catalog/modules/container/aks"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  # Kubernetes configuration
  kubernetes_version        = var.kubernetes_version
  automatic_channel_upgrade = var.automatic_channel_upgrade
  sku_tier                  = var.sku_tier

  # Identity
  identity_type = "UserAssigned"
  identity_ids  = [module.aks_identity.id]

  kubelet_identity = {
    client_id                 = module.kubelet_identity.client_id
    object_id                 = module.kubelet_identity.principal_id
    user_assigned_identity_id = module.kubelet_identity.id
  }

  # Azure AD Integration
  local_account_disabled = true
  azure_rbac_enabled     = true
  admin_group_object_ids = var.admin_group_object_ids

  # Network Configuration
  network_profile_preset = var.network_profile_preset
  service_cidr           = var.service_cidr
  dns_service_ip         = var.dns_service_ip
  outbound_type          = var.outbound_type

  load_balancer_profile = var.outbound_type == "loadBalancer" ? {
    managed_outbound_ip_count = 1
  } : null

  # Default Node Pool (System)
  default_node_pool = merge(var.system_node_pool, {
    vnet_subnet_id = module.virtual_network.subnet_ids["aks-system"]
  })

  # Additional Node Pools
  additional_node_pools = {
    for name, config in var.additional_node_pools : name => merge(config, {
      vnet_subnet_id = lookup(config, "vnet_subnet_id", module.virtual_network.subnet_ids["aks-user"])
    })
  }

  # Windows Support
  enable_windows_node_pools = var.enable_windows_node_pools
  windows_admin_username    = var.windows_admin_username
  windows_admin_password    = var.windows_admin_password

  # Monitoring
  oms_agent_enabled          = var.oms_agent_enabled
  log_analytics_workspace_id = module.log_analytics.id

  # Add-ons
  key_vault_secrets_provider_enabled = var.key_vault_secrets_provider_enabled
  azure_policy_enabled               = var.azure_policy_enabled
  oidc_issuer_enabled                = var.oidc_issuer_enabled
  workload_identity_enabled          = var.workload_identity_enabled

  diagnostic_settings = {
    log_analytics_workspace_id = module.log_analytics.id
  }

  additional_tags = var.additional_tags

  depends_on = [
    azurerm_role_assignment.aks_kubelet_mio  # Ensure AKS identity has MIO role on kubelet identity
  ]
}
