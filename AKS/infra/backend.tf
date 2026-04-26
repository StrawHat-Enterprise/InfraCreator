# =============================================================================
# AKS Infrastructure - Remote Backend Configuration
# =============================================================================
# Configure this with the values from the backend infrastructure outputs
# 
# IMPORTANT: Update these values after deploying the backend infrastructure
# The backend values can be obtained from:
#   cd ../backend && terraform output backend_config
# =============================================================================

terraform {
  backend "azurerm" {
    # These values should be configured via:
    # - Environment variables (TF_VAR_*)
    # - Terraform init -backend-config
    # - CI/CD pipeline variables
    #
    # Example:
    # terraform init \
    #   -backend-config="resource_group_name=rg-acme-tfstate-eus-shared" \
    #   -backend-config="storage_account_name=stacmetfstateeus001" \
    #   -backend-config="container_name=tfstate" \
    #   -backend-config="key=aks-infra.tfstate"
  }
}
