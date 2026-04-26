# =============================================================================
# Terraform Backend Infrastructure - Outputs
# =============================================================================
# These outputs provide the values needed to configure the backend in the
# main infrastructure configuration.
# =============================================================================

# =============================================================================
# Resource Group Outputs
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group for Terraform state"
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
# Storage Account Outputs
# =============================================================================

output "storage_account_name" {
  description = "Name of the storage account for Terraform state"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage_account.id
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL"
  value       = module.storage_account.primary_blob_endpoint
}

# =============================================================================
# Backend Configuration Output
# =============================================================================

output "backend_config" {
  description = "Backend configuration for use in main infrastructure"
  value = {
    resource_group_name  = module.resource_group.name
    storage_account_name = module.storage_account.name
    container_name       = "tfstate"
  }
}

output "backend_config_snippet" {
  description = "Terraform backend configuration snippet"
  value       = <<-EOT
    # Add this to your main infrastructure terraform block:
    backend "azurerm" {
      resource_group_name  = "${module.resource_group.name}"
      storage_account_name = "${module.storage_account.name}"
      container_name       = "tfstate"
      key                  = "infra.tfstate"
    }
  EOT
}
