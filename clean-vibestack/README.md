# VibeStack - OCI Always Free Deployments

Deploy KASM Workspaces and/or Coolify on Oracle Cloud Infrastructure using only Always Free tier resources.

VibeStack can be deployed in different configurations to match your needs. All deployment options utilize [Oracle Cloud Infrastructure][oci] Always Free tier resources that can be used indefinitely.

| [Single Server: `VibeStack Coolify` or `VibeStack KASM`](#single-server-deployments) | [Full Stack: `VibeStack Full`](#vibestack-full) |
|---|---|
| Deploy **either** Coolify or KASM individually using half of your Always Free allocation. <br/><br/> **Coolify**: Self-hosted app platform (like Vercel/Netlify) <br/> • 2 OCPUs, 12GB RAM, 100GB storage <br/><br/> **KASM**: Remote workspace server <br/> • 2 OCPUs, 12GB RAM, 60GB storage | Full deployment with **both** servers maximizing your Always Free tier. <br/><br/> **Includes**: <br/> • KASM Workspaces server <br/> • Coolify platform server <br/> • Shared networking infrastructure <br/> • 4 OCPUs, 24GB RAM, 160GB storage total |
| **VibeStack Coolify:** [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/oci-cloudnative/releases/latest/download/vibestack-coolify.zip) <br/><br/> **VibeStack KASM:** [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/oci-cloudnative/releases/latest/download/vibestack-kasm.zip) | **VibeStack Full:** [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/oci-cloudnative/releases/latest/download/vibestack-full.zip) |

```text
vibestack
└── terraform
    ├── coolify-only
    ├── kasm-only
    └── vibestack
```

[oci]: https://cloud.oracle.com

## Single Server Deployments

Choose one of these options if you want to deploy just a single server and keep half your Always Free resources available for other uses.

### VibeStack Coolify
- **What**: Self-hosted application deployment platform (like Vercel/Netlify/Heroku)
- **Resources**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB storage)
- **Perfect for**: Developers wanting their own PaaS for deploying Docker containers, static sites, and databases
- **Ports**: 22 (SSH), 80/443 (HTTP/S), 3000 (Coolify UI)

### VibeStack KASM
- **What**: Browser-based remote workspace server with containerized desktops
- **Resources**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB storage)
- **Perfect for**: Remote development environments, secure browsing, virtual desktops
- **Ports**: 22 (SSH), 80/443 (HTTP/S), plus any custom ports you configure

## VibeStack Full

The complete deployment uses your full Always Free allocation to run both servers together.

- **KASM Server**: Remote workspace hosting (2 OCPUs, 12GB RAM, 60GB storage)
- **Coolify Server**: App deployment platform (2 OCPUs, 12GB RAM, 100GB storage)
- **Shared Infrastructure**: VCN, subnet, internet gateway, and security rules
- **Total Resources**: 4 OCPUs, 24GB RAM, 160GB storage (80% of free tier)

## 🔧 All Packages Include

- **Custom compartment** (you name it during deployment)
- **Ubuntu 22.04 LTS** (or Oracle Linux option)
- **Public networking** with security groups
- **SSH access** with your public key
- **Always Free tier compatible** - no charges

## 📖 Documentation

- [VibeStack Recommended Setup](docs/oci-vibestack-recommended-setup.md)
- [Deploy Button Specification](docs/deploy-button-specification.md)
- [Termius Import Generator](docs/termius-import.md) - Generate SSH client import files
- [Log Management](docs/log-management.md) - Secure handling of deployment logs

## 🔧 Post-Deployment Tools

### Option 1: Direct Import (if Terraform is available)

```bash
# Linux/macOS
./generate-termius-import.sh

# Windows PowerShell
.\generate-termius-import.ps1
```

### Option 2: From Saved Logs (recommended for OCI Resource Manager)

```bash
# 1. Save your deployment log securely
./manage-deployment-logs.sh save-state path/to/terraform-state.txt

# 2. Generate import files from saved log
./manage-deployment-logs.sh import-from-log

# 3. Import to Termius, then cleanup
./manage-deployment-logs.sh cleanup
```

This workflow securely handles sensitive deployment data and creates import files for Termius or other SSH clients. All log files are Git-ignored for security. See the [Log Management documentation](docs/log-management.md) for details.

## 🛠️ Manual Deployment

If you prefer Terraform CLI instead of the deploy buttons:

```bash
# Clone and navigate
git clone https://github.com/evolv3ai/oci-cloudnative.git
cd oci-cloudnative/clean-vibestack/terraform/vibestack  # or coolify-only/ or kasm-only/

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials

# Deploy
terraform init
terraform apply

# Cleanup when done
terraform destroy
```

## 🧹 Resource Cleanup

For complete resource removal when Terraform state is lost or corrupted:

```bash
# Complete compartment cleanup (IRREVERSIBLE!)
./cleanup-compartment.sh <compartment-ocid>

# Example:
./cleanup-compartment.sh ocid1.compartment.oc1..aaaaaaaae5v3sal4r6df2hrucviwerue5k3trdiln5buhh7wggjjgw2f7wua
```

⚠️ **Warning**: This script permanently deletes ALL resources in the specified compartment. It follows proper dependency order to avoid hanging deletions:

1. Volume attachments → 2. Compute instances → 3. Block volumes → 4. Boot volumes
5. Load balancers → 6. Subnets → 7. Internet gateways → 8. Route tables
9. Security lists → 10. VCNs → 11. Compartment

## 💡 Why VibeStack?

- **Always Free**: Uses Oracle Cloud's generous Always Free tier
- **Proven Stack**: KASM + Coolify is a powerful combination
- **Compartmentalized**: Clean organization with custom naming
- **Ubuntu**: Modern, well-supported OS with excellent ARM compatibility
- **One-Click**: Deploy buttons make it trivial to get started

## 🔗 Related Projects

- [KASM Workspaces](https://kasmweb.com/) - Containerized workspaces
- [Coolify](https://coolify.io/) - Self-hosted app deployment platform
- [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/) - Generous free tier

## 📄 License

Released under the Universal Permissive License v1.0