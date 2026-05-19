# =============================================================================
# Production Environment - Linux and Windows Node Pools
# =============================================================================
# This configuration creates a production AKS cluster with both Linux and
# Windows node pools, suitable for running .NET/Windows workloads alongside
# Linux containers.
# =============================================================================

# =============================================================================
# Global Settings
# =============================================================================

organization_prefix = "acme"
application_name    = "platform"
environment         = "prod"
location            = "eastus"

cost_center = "Engineering"
owner       = "platform-team@example.com"

additional_tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  Team        = "Platform"
  Criticality = "High"
}

# =============================================================================
# Azure AD / RBAC
# =============================================================================

# Add your Azure AD group object IDs for cluster admin access
# IMPORTANT: Configure this with your production admin groups
admin_group_object_ids = []

# =============================================================================
# Network Configuration
# =============================================================================

vnet_address_space       = ["10.0.0.0/16"]
subnet_aks_system        = "10.0.0.0/22" # 1022 IPs for system nodes
subnet_aks_user          = "10.0.4.0/22" # 1022 IPs for user nodes
subnet_private_endpoints = "10.0.8.0/24" # 254 IPs for private endpoints
create_nat_gateway       = true

# =============================================================================
# AKS Configuration
# =============================================================================

kubernetes_version        = "1.29"
automatic_channel_upgrade = "patch"
sku_tier                  = "Standard" # Required for production SLA

network_profile_preset = "azure_cni_overlay"
service_cidr           = "10.96.0.0/16"
dns_service_ip         = "10.96.0.10"
outbound_type          = "userAssignedNATGateway"

# =============================================================================
# System Node Pool (Linux)
# =============================================================================

system_node_pool = {
  name                         = "system"
  vm_size                      = "Standard_D4s_v3"
  min_count                    = 3 # HA for production
  max_count                    = 5
  max_pods                     = 30
  os_disk_size_gb              = 128
  os_disk_type                 = "Managed"
  os_sku                       = "Ubuntu"
  zones                        = ["1", "2", "3"] # Zone redundancy
  only_critical_addons_enabled = true
  node_labels = {
    "nodepool-type" = "system"
    "environment"   = "production"
  }
}

# =============================================================================
# Additional Node Pools (Linux + Windows)
# =============================================================================

additional_node_pools = {
  # Linux user pool for general workloads
  linuxapps = {
    vm_size   = "Standard_D4s_v3"
    os_type   = "Linux"
    os_sku    = "Ubuntu"
    min_count = 3
    max_count = 20
    max_pods  = 30
    zones     = ["1", "2", "3"]
    mode      = "User"
    node_labels = {
      "nodepool-type" = "user"
      "os"            = "linux"
      "workload"      = "general"
      "environment"   = "production"
    }
    node_taints = []
  }

  # Linux pool for memory-intensive workloads
  linux-memory = {
    vm_size   = "Standard_E4s_v3" # Memory optimized
    os_type   = "Linux"
    os_sku    = "Ubuntu"
    min_count = 0
    max_count = 10
    max_pods  = 30
    zones     = ["1", "2", "3"]
    mode      = "User"
    node_labels = {
      "nodepool-type" = "user"
      "os"            = "linux"
      "workload"      = "memory-intensive"
      "environment"   = "production"
    }
    node_taints = ["workload=memory:NoSchedule"]
  }

  # Windows pool for .NET Framework workloads
  win-apps = {
    vm_size   = "Standard_D4s_v3"
    os_type   = "Windows"
    os_sku    = "Windows2022"
    min_count = 2
    max_count = 10
    max_pods  = 30
    zones     = ["1", "2", "3"]
    mode      = "User"
    node_labels = {
      "nodepool-type" = "user"
      "os"            = "windows"
      "workload"      = "dotnet"
      "environment"   = "production"
    }
    node_taints = ["os=windows:NoSchedule"]
  }

  # Windows pool for legacy .NET Framework (Windows 2019)
  win-legacy = {
    vm_size   = "Standard_D4s_v3"
    os_type   = "Windows"
    os_sku    = "Windows2019"
    min_count = 0
    max_count = 5
    max_pods  = 30
    zones     = ["1", "2", "3"]
    mode      = "User"
    node_labels = {
      "nodepool-type" = "user"
      "os"            = "windows"
      "os-version"    = "2019"
      "workload"      = "dotnet-legacy"
      "environment"   = "production"
    }
    node_taints = ["os=windows-legacy:NoSchedule"]
  }

  # Spot pool for cost-effective batch workloads
  spot = {
    vm_size         = "Standard_D4s_v3"
    os_type         = "Linux"
    os_sku          = "Ubuntu"
    min_count       = 0
    max_count       = 10
    max_pods        = 30
    zones           = ["1", "2", "3"]
    mode            = "User"
    priority        = "Spot"
    spot_max_price  = -1 # Pay up to on-demand price
    eviction_policy = "Delete"
    node_labels = {
      "nodepool-type"                         = "spot"
      "kubernetes.azure.com/scalesetpriority" = "spot"
    }
    node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
  }
}

# =============================================================================
# Windows Node Pool Configuration
# =============================================================================

enable_windows_node_pools = true
windows_admin_username    = "azureadmin"
# IMPORTANT: Set this via environment variable or secret management
# windows_admin_password = "REPLACE_WITH_SECURE_PASSWORD"
# Use: TF_VAR_windows_admin_password or Azure Key Vault

# =============================================================================
# Monitoring Configuration
# =============================================================================

log_analytics_retention_days = 90 # Longer retention for production
oms_agent_enabled            = true

# =============================================================================
# Add-ons Configuration
# =============================================================================

key_vault_secrets_provider_enabled = true
azure_policy_enabled               = true # Enable for production governance
oidc_issuer_enabled                = true
workload_identity_enabled          = true

# =============================================================================
# Container Registry Configuration
# =============================================================================

acr_sku           = "Premium" # Premium for geo-replication and advanced features
acr_admin_enabled = false

# =============================================================================
# Storage Configuration
# =============================================================================

storage_replication_type = "ZRS" # Zone-redundant for production

# =============================================================================
# Key Vault Configuration
# =============================================================================

key_vault_purge_protection = true # Required for production
key_vault_soft_delete_days = 90
