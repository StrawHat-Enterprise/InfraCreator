#!/bin/bash
# =============================================================================
# Setup Federated Credentials for GitHub Actions OIDC
# =============================================================================
# This script creates an Azure AD App Registration with federated credentials
# for both dev and prod environments.
#
# Usage:
#   ./setup-federated-credentials.sh <github-org> <github-repo> [app-name]
#
# Example:
#   ./setup-federated-credentials.sh myorg InfraCreator sp-infracreator-github
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validate arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <github-org> <github-repo> [app-name]${NC}"
    echo -e "Example: $0 myorg InfraCreator sp-infracreator-github"
    exit 1
fi

GITHUB_ORG="$1"
GITHUB_REPO="$2"
APP_NAME="${3:-sp-${GITHUB_REPO,,}-github}"

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}Setting up Federated Credentials${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "GitHub Repository: ${GREEN}${GITHUB_ORG}/${GITHUB_REPO}${NC}"
echo -e "App Name: ${GREEN}${APP_NAME}${NC}"
echo ""

# Check if logged into Azure
echo -e "${YELLOW}Checking Azure login...${NC}"
if ! az account show &>/dev/null; then
    echo -e "${RED}Not logged into Azure. Running 'az login'...${NC}"
    az login
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "Subscription: ${GREEN}${SUBSCRIPTION_ID}${NC}"
echo -e "Tenant: ${GREEN}${TENANT_ID}${NC}"
echo ""

# =============================================================================
# Step 1: Create or get App Registration
# =============================================================================
echo -e "${YELLOW}Step 1: Creating/Getting App Registration...${NC}"

# Check if app already exists
EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_APP" ] && [ "$EXISTING_APP" != "null" ]; then
    echo -e "${GREEN}App already exists: ${EXISTING_APP}${NC}"
    CLIENT_ID="$EXISTING_APP"
else
    echo -e "Creating new App Registration..."
    CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
    echo -e "${GREEN}Created App: ${CLIENT_ID}${NC}"
fi

# Get Object ID for federated credentials
OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
echo -e "Object ID: ${GREEN}${OBJECT_ID}${NC}"

# =============================================================================
# Step 2: Create Service Principal (if not exists)
# =============================================================================
echo -e ""
echo -e "${YELLOW}Step 2: Creating/Getting Service Principal...${NC}"

SP_EXISTS=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv 2>/dev/null || echo "")

if [ -n "$SP_EXISTS" ]; then
    echo -e "${GREEN}Service Principal already exists${NC}"
    SP_OBJECT_ID="$SP_EXISTS"
else
    SP_OBJECT_ID=$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)
    echo -e "${GREEN}Created Service Principal${NC}"
fi

# =============================================================================
# Step 3: Create Federated Credentials for each environment
# =============================================================================
echo -e ""
echo -e "${YELLOW}Step 3: Creating Federated Credentials...${NC}"

# Function to create federated credential
create_federated_credential() {
    local name="$1"
    local subject="$2"
    local description="$3"
    
    echo -e "  Creating: ${name}..."
    
    # Check if credential already exists
    EXISTING=$(az ad app federated-credential list --id "$OBJECT_ID" --query "[?name=='$name'].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING" ]; then
        echo -e "    ${YELLOW}Already exists, skipping...${NC}"
        return
    fi
    
    az ad app federated-credential create --id "$OBJECT_ID" --parameters "{
        \"name\": \"$name\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"$subject\",
        \"description\": \"$description\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }" >/dev/null
    
    echo -e "    ${GREEN}Created!${NC}"
}

# Create credentials for environments
create_federated_credential \
    "github-${GITHUB_REPO,,}-env-dev" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:dev" \
    "GitHub Actions - Dev Environment"

create_federated_credential \
    "github-${GITHUB_REPO,,}-env-prod" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:prod" \
    "GitHub Actions - Prod Environment"

# Create credential for main branch (for backend setup)
create_federated_credential \
    "github-${GITHUB_REPO,,}-branch-main" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main" \
    "GitHub Actions - Main Branch"

# Create credential for issue comments (IssueOps without environment)
create_federated_credential \
    "github-${GITHUB_REPO,,}-issueops" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request" \
    "GitHub Actions - Pull Requests"

# =============================================================================
# Step 4: Assign Azure Roles
# =============================================================================
echo -e ""
echo -e "${YELLOW}Step 4: Assigning Azure Roles...${NC}"

assign_role() {
    local role="$1"
    local scope="$2"
    
    echo -e "  Assigning: ${role}..."
    
    # Check if role already assigned
    EXISTING=$(az role assignment list --assignee "$SP_OBJECT_ID" --role "$role" --scope "$scope" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING" ]; then
        echo -e "    ${YELLOW}Already assigned, skipping...${NC}"
        return
    fi
    
    az role assignment create \
        --assignee-object-id "$SP_OBJECT_ID" \
        --assignee-principal-type ServicePrincipal \
        --role "$role" \
        --scope "$scope" >/dev/null
    
    echo -e "    ${GREEN}Assigned!${NC}"
}

# Contributor for creating resources
assign_role "Contributor" "/subscriptions/${SUBSCRIPTION_ID}"

# User Access Administrator for RBAC assignments
assign_role "User Access Administrator" "/subscriptions/${SUBSCRIPTION_ID}"

# =============================================================================
# Summary
# =============================================================================
echo -e ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "Add these secrets to your GitHub repository:"
echo -e "${YELLOW}Settings → Secrets and variables → Actions → New repository secret${NC}"
echo ""
echo -e "┌─────────────────────────┬──────────────────────────────────────┐"
echo -e "│ Secret Name             │ Value                                │"
echo -e "├─────────────────────────┼──────────────────────────────────────┤"
printf "│ %-23s │ %-36s │\n" "AZURE_CLIENT_ID" "$CLIENT_ID"
printf "│ %-23s │ %-36s │\n" "AZURE_TENANT_ID" "$TENANT_ID"
printf "│ %-23s │ %-36s │\n" "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
echo -e "└─────────────────────────┴──────────────────────────────────────┘"
echo ""
echo -e "${YELLOW}Also create GitHub Environments:${NC}"
echo -e "Settings → Environments → New environment"
echo -e "  • ${GREEN}dev${NC}"
echo -e "  • ${GREEN}prod${NC} (optionally add required reviewers)"
echo ""
echo -e "${YELLOW}For production Windows nodes, also add:${NC}"
echo -e "  WINDOWS_ADMIN_PASSWORD (in prod environment secrets)"
echo ""

# Save config to file
CONFIG_FILE="federated-credentials-config.json"
cat > "$CONFIG_FILE" <<EOF
{
  "app_name": "$APP_NAME",
  "client_id": "$CLIENT_ID",
  "tenant_id": "$TENANT_ID",
  "subscription_id": "$SUBSCRIPTION_ID",
  "object_id": "$OBJECT_ID",
  "sp_object_id": "$SP_OBJECT_ID",
  "github_org": "$GITHUB_ORG",
  "github_repo": "$GITHUB_REPO",
  "credentials": [
    "github-${GITHUB_REPO,,}-env-dev",
    "github-${GITHUB_REPO,,}-env-prod",
    "github-${GITHUB_REPO,,}-branch-main",
    "github-${GITHUB_REPO,,}-issueops"
  ]
}
EOF

echo -e "Configuration saved to: ${GREEN}${CONFIG_FILE}${NC}"
