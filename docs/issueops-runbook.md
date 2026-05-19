# IssueOps AKS Deployment Runbook

## Prerequisites

| Item | Details |
|------|---------|
| **GitHub Issue** | Create issue using AKS deployment template |
| **Repository** | `StrawHat-Enterprise/InfraCreator` |
| **Required Secrets** | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `GH_PAT` |
| **Browser Session** | Logged into GitHub with permission to comment on issues |

---

## Deployment Sequence

### Step 1: Set AKS Backend
**Command:** `/set-aks-backend`

**What it does:**
- Creates Azure resource group for Terraform state
- Creates Azure Storage Account
- Creates blob container `tfstate`
- Saves backend config for subsequent steps

**Success Criteria:**
- Workflow status: ✅ Success
- Comment shows: "AKS Backend Created Successfully"
- Storage account created in Azure

**Wait for:** Workflow completion (~2-3 min)

---

### Step 2: Build AKS Infrastructure
**Command:** `/build-aks-dev` or `/build-aks-prod`

**What it does:**
- Runs `terraform init` with backend from Step 1
- Runs `terraform plan`
- Runs `terraform apply`
- Creates AKS cluster, node pools, networking, Key Vault

**Success Criteria:**
- Workflow status: ✅ Success
- Comment shows: "AKS Cluster Deployed Successfully"
- AKS cluster visible in Azure portal

**Wait for:** Workflow completion (~5-8 min)

**Common Failures:**
| Error | Solution |
|-------|----------|
| Reserved tag name (PoolName) | Update Azure-Catalog module tag key |
| Availability zone mismatch | Check node pool zone configuration |
| Quota exceeded | Request quota increase in Azure |

---

### Step 3: Bootstrap Flux GitOps
**Command:** `/bootstrap-flux-dev` or `/bootstrap-flux-prod`

**What it does:**
- Gets AKS credentials
- Installs Flux on cluster
- Configures GitOps repo connection
- Pushes GitHub PAT to Key Vault
- Sets up External Secrets Operator integration

**Success Criteria:**
- Workflow status: ✅ Success
- Comment shows: "Flux Bootstrap + Key Vault Secrets Complete"
- `flux check` passes on cluster

**Wait for:** Workflow completion (~1-2 min)

---

### Step 4: Deploy Runners
**Command:** `/deploy-runners env=dev flavor=gh-supported types=dind,kubernetes-pvc,kubernetes-novolume`

**Parameters:**
| Param | Values | Description |
|-------|--------|-------------|
| `env` | `dev`, `prod` | Target environment |
| `flavor` | `gh-supported`, `community` | Chart source |
| `types` | `dind`, `kubernetes-pvc`, `kubernetes-novolume` | Runner modes |

**What it does:**
- Creates Kustomization overlays for each runner type
- Configures HelmReleases pointing to GHCR charts
- Flux reconciles and deploys ARC runner scale sets

**Success Criteria:**
- Workflow status: ✅ Success
- Comment shows: "Runner Deployment Complete"

**Wait for:** Workflow completion (~1-2 min)

---

### Step 5: Check Runner Status
**Command:** `/status-runners-dev` or `/status-runners-prod`

**What it does:**
- Runs `flux check` on cluster
- Gets Kustomization status
- Gets HelmRelease status
- Gets runner pod status
- Posts formatted status report

**Success Criteria:**
- Workflow status: ✅ Success
- Comment shows: "📊 Runner Status Report"
- All Kustomizations show `Ready: True`
- All HelmReleases show `Ready: True`

**Wait for:** Workflow completion (~30-60 sec)

---

## Verification Commands (Manual)

```bash
# Get AKS credentials
az aks get-credentials -g <resource-group> -n <aks-name>

# Check Flux
flux check
flux get kustomizations
flux get helmreleases -A

# Check runners
kubectl get pods -n arc-runners
kubectl get autoscalingrunnerset -A
```

---

## Rollback Procedures

### Destroy AKS Infrastructure
**Command:** `/destroy-aks-dev` or `/destroy-aks-prod`

### Uninstall Flux
```bash
flux uninstall
```

### Force Sync
**Command:** `/sync-runners-dev` or `/sync-runners-prod`

---

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| Workflow fails at terraform | Check Azure permissions | Verify OIDC federation |
| Flux not syncing | `flux get sources git` | Check GitHub PAT in Key Vault |
| Runners not registering | Check ExternalSecret | Verify `github-pat` secret exists |
| Status command fails | Check workflow logs | May be JS syntax issue in workflow |

---

## Notes
- Each step must complete successfully before proceeding to next
- Monitor workflow runs at: `Actions > IssueOps: Bootstrap Flux & Action Runners`
- All commands are posted as comments on the GitHub issue
