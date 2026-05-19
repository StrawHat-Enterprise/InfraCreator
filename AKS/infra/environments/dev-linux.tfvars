# =============================================================================
# Development Environment - Linux Node Pools Only
# =============================================================================
# This configuration creates a development AKS cluster with Linux-only
# node pools, optimized for cost and developer workflows.
# =============================================================================

# =============================================================================
# Global Settings
# =============================================================================

organization_prefix = "acme"
application_name    = "platform"
environment         = "dev"
location            = "eastus"

cost_center = "Engineering"
owner       = "dev-team@example.com"

additional_tags = {
  Environment = "Development"
  ManagedBy   = "Terraform"
  Team        = "Platform"
}

# =============================================================================
# Azure AD / RBAC
# =============================================================================

# Add your Azure AD group object IDs for cluster admin access
admin_group_object_ids = ["be2a05c2-eba7-42cc-8f1d-375c25527779"]

# K8s admin user/group Object ID
k8s_admin_object_id = "be2a05c2-eba7-42cc-8f1d-375c25527779"

# =============================================================================
# Network Configuration
# =============================================================================

vnet_address_space       = ["10.0.0.0/16"]
subnet_aks_system        = "10.0.0.0/22"
subnet_aks_user          = "10.0.4.0/22"
subnet_private_endpoints = "10.0.8.0/24"
create_nat_gateway       = true

# =============================================================================
# AKS Configuration
# =============================================================================

kubernetes_version        = "1.33"
automatic_channel_upgrade = "patch"
sku_tier                  = "Free" # Use Standard for SLA in production

network_profile_preset = "azure_cni_overlay"
service_cidr           = "10.96.0.0/16"
dns_service_ip         = "10.96.0.10"
outbound_type          = "userAssignedNATGateway"

# =============================================================================
# System Node Pool (Linux)
# =============================================================================

system_node_pool = {
  name                         = "system"
  vm_size                      = "Standard_D2s_v3" # Cost-effective for dev
  min_count                    = 1                 # Min 1 for dev
  max_count                    = 3
  max_pods                     = 30
  os_disk_size_gb              = 128
  os_disk_type                 = "Managed"
  os_sku                       = "Ubuntu"
  zones                        = ["2"]
  only_critical_addons_enabled = true
  node_labels = {
    "nodepool-type" = "system"
    "environment"   = "dev"
  }
}

# =============================================================================
# Additional Node Pools (Linux Only)
# =============================================================================

additional_node_pools = {
  # Linux user pool for general workloads
  linuxapps = {
    vm_size   = "Standard_D4s_v3"
    os_type   = "Linux"
    os_sku    = "Ubuntu"
    min_count = 1
    max_count = 5
    max_pods  = 30
    zones     = ["2"]
    mode      = "User"
    node_labels = {
      "nodepool-type" = "user"
      "workload"      = "general"
      "environment"   = "dev"
    }
    node_taints = []
  }

  # Optional: Spot pool for batch/test workloads (cost savings)
  spot = {
    vm_size         = "Standard_D4s_v3"
    os_type         = "Linux"
    os_sku          = "Ubuntu"
    min_count       = 0
    max_count       = 3
    max_pods        = 30
    zones           = ["2"]
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

# Windows is disabled for this dev environment
enable_windows_node_pools = false

# =============================================================================
# Monitoring Configuration
# =============================================================================

log_analytics_retention_days = 30
oms_agent_enabled            = true

# =============================================================================
# Add-ons Configuration
# =============================================================================

key_vault_secrets_provider_enabled = true
azure_policy_enabled               = false # Enable in production
oidc_issuer_enabled                = true
workload_identity_enabled          = true

# =============================================================================
# Container Registry Configuration
# =============================================================================

acr_sku           = "Standard" # Basic or Standard for dev
acr_admin_enabled = false

# =============================================================================
# Storage Configuration
# =============================================================================

storage_replication_type = "LRS" # LRS is sufficient for dev

# =============================================================================
# Key Vault Configuration
# =============================================================================

key_vault_purge_protection = false # Disable for dev (easier cleanup)
key_vault_soft_delete_days = 7
