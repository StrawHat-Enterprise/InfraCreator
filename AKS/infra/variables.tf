# =============================================================================
# AKS Infrastructure - Variables
# =============================================================================

# =============================================================================
# Global Variables
# =============================================================================

variable "organization_prefix" {
  description = "Organization prefix for resource naming (3-8 characters)"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{2,7}$", var.organization_prefix))
    error_message = "Organization prefix must be 3-8 alphanumeric characters, starting with a letter."
  }
}

variable "application_name" {
  description = "Application or workload name"
  type        = string
}

variable "environment" {
  description = "Environment: development, dev, staging, stg, production, prod"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner email or team"
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Azure AD / RBAC Configuration
# =============================================================================

variable "admin_group_object_ids" {
  description = "List of Azure AD group object IDs for AKS cluster admin access"
  type        = list(string)
  default     = []
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_aks_system" {
  description = "Address prefix for AKS system node pool subnet"
  type        = string
  default     = "10.0.0.0/22"
}

variable "subnet_aks_user" {
  description = "Address prefix for AKS user node pool subnet"
  type        = string
  default     = "10.0.4.0/22"
}

variable "subnet_private_endpoints" {
  description = "Address prefix for private endpoints subnet"
  type        = string
  default     = "10.0.8.0/24"
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway for outbound connectivity"
  type        = bool
  default     = true
}

# =============================================================================
# AKS Configuration
# =============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "automatic_channel_upgrade" {
  description = "Automatic upgrade channel (none, patch, stable, rapid, node-image)"
  type        = string
  default     = "patch"
}

variable "sku_tier" {
  description = "AKS SKU tier (Free or Standard)"
  type        = string
  default     = "Free"
}

variable "network_profile_preset" {
  description = "Network profile preset (kubenet, azure_cni, azure_cni_overlay, azure_cni_cilium)"
  type        = string
  default     = "azure_cni_overlay"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.96.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for DNS service within service_cidr"
  type        = string
  default     = "10.96.0.10"
}

variable "outbound_type" {
  description = "Outbound type (loadBalancer, userAssignedNATGateway, userDefinedRouting)"
  type        = string
  default     = "userAssignedNATGateway"
}

# =============================================================================
# Default (System) Node Pool
# =============================================================================

variable "system_node_pool" {
  description = "Configuration for the system (default) node pool"
  type = object({
    name                         = optional(string, "system")
    vm_size                      = string
    min_count                    = optional(number, 2)
    max_count                    = optional(number, 5)
    max_pods                     = optional(number, 30)
    os_disk_size_gb              = optional(number, 128)
    os_disk_type                 = optional(string, "Managed")
    os_sku                       = optional(string, "Ubuntu")
    zones                        = optional(list(string), ["1", "2", "3"])
    only_critical_addons_enabled = optional(bool, true)
    node_labels                  = optional(map(string), {})
  })
  default = {
    vm_size   = "Standard_D4s_v3"
    min_count = 2
    max_count = 5
  }
}

# =============================================================================
# Additional Node Pools
# =============================================================================

variable "additional_node_pools" {
  description = <<-EOF
    Map of additional node pools. Each pool can have:
    - vm_size: Required VM size
    - os_type: "Linux" (default) or "Windows"
    - os_sku: For Linux: "Ubuntu", "AzureLinux". For Windows: "Windows2019", "Windows2022"
    - min_count, max_count, node_count
    - max_pods, os_disk_size_gb, os_disk_type
    - zones, mode (User/System)
    - priority (Regular/Spot), spot_max_price, eviction_policy
    - node_labels, node_taints
  EOF
  type        = any
  default     = {}
}

variable "enable_windows_node_pools" {
  description = "Enable Windows node pool support"
  type        = bool
  default     = false
}

variable "windows_admin_username" {
  description = "Admin username for Windows node pools"
  type        = string
  default     = "azureadmin"
}

variable "windows_admin_password" {
  description = "Admin password for Windows node pools (required if enable_windows_node_pools = true)"
  type        = string
  default     = null
  sensitive   = true
}

# =============================================================================
# Monitoring Configuration
# =============================================================================

variable "log_analytics_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "oms_agent_enabled" {
  description = "Enable Azure Monitor Container Insights"
  type        = bool
  default     = true
}

# =============================================================================
# Add-ons Configuration
# =============================================================================

variable "key_vault_secrets_provider_enabled" {
  description = "Enable Key Vault secrets provider CSI driver"
  type        = bool
  default     = false
}

variable "azure_policy_enabled" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = false
}

variable "oidc_issuer_enabled" {
  description = "Enable OIDC issuer for workload identity"
  type        = bool
  default     = true
}

variable "workload_identity_enabled" {
  description = "Enable workload identity"
  type        = bool
  default     = true
}

# =============================================================================
# Container Registry Configuration
# =============================================================================

variable "acr_sku" {
  description = "ACR SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

variable "acr_admin_enabled" {
  description = "Enable ACR admin user"
  type        = bool
  default     = false
}

# =============================================================================
# Storage Account Configuration
# =============================================================================

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

# =============================================================================
# Key Vault Configuration
# =============================================================================

variable "key_vault_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

variable "key_vault_soft_delete_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 7
}
