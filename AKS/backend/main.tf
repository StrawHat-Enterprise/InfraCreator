# =============================================================================
# Terraform Backend Infrastructure
# =============================================================================
# This creates the storage account and resource group needed for Terraform
# remote state. Deploy this FIRST before the main infrastructure.
#
# Usage:
#   In the CI/CD pipeline, clone both repos:
#   - InfraCreator (this repo)
#   - Azure-Catalog (module catalog)
#
#   The modules are referenced relative to the pipeline workspace.
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
# Resource Group for Terraform State
# =============================================================================

module "resource_group" {
  source = "../../../Azure-Catalog/modules/core/resource-group"

  naming      = module.naming.names
  location    = var.location
  common_tags = module.naming.common_tags

  additional_tags = merge(var.additional_tags, {
    Purpose = "Terraform State Storage"
  })

  # Enable delete lock for production state storage
  enable_delete_lock = true
}

# =============================================================================
# Storage Account for Terraform State
# =============================================================================

module "storage_account" {
  source = "../../../Azure-Catalog/modules/storage/storage-account"

  naming              = module.naming.names
  location            = var.location
  resource_group_name = module.resource_group.name
  common_tags         = module.naming.common_tags

  # Storage configuration for state files
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # Security settings
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  # Enable versioning for state file protection
  blob_properties = {
    versioning_enabled       = true
    delete_retention_days    = 30
    container_delete_retention_days = 30
  }

  # Create containers for tfstate
  containers = var.state_containers

  additional_tags = merge(var.additional_tags, {
    Purpose = "Terraform State Storage"
  })
}
