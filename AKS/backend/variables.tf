# =============================================================================
# Terraform Backend Infrastructure - Variables
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
  description = "Application name for the infrastructure"
  type        = string
  default     = "tfstate"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "shared"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
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

# =============================================================================
# Storage Account Configuration
# =============================================================================

variable "storage_replication_type" {
  description = "Storage replication type (LRS, GRS, ZRS, GZRS)"
  type        = string
  default     = "GRS"
}

variable "state_containers" {
  description = "Map of state containers to create"
  type        = map(object({
    access_type = optional(string, "private")
  }))
  default = {
    tfstate = {
      access_type = "private"
    }
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
