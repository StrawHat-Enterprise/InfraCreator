# =============================================================================
# Terraform Backend Infrastructure - Versions & Providers
# =============================================================================
# This configuration manages the Terraform state storage infrastructure
# Run this FIRST before applying the main infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
