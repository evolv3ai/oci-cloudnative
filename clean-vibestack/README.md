# VibeStack - OCI Always Free Deployments

Deploy KASM Workspaces and/or Coolify on Oracle Cloud Infrastructure using only Always Free tier resources.

## 🚀 Quick Deploy Options

| Package | Description | Deploy |
|---------|-------------|--------|
| **VibeStack Complete** | Both KASM + Coolify servers (4 OCPUs, 24GB RAM) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/vibestack-oci/releases/latest/download/vibestack-complete.zip) |
| **Coolify Only** | Self-hosted app platform (2 OCPUs, 12GB RAM) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/vibestack-oci/releases/latest/download/coolify-only.zip) |
| **KASM Only** | Remote workspace server (2 OCPUs, 12GB RAM) | [![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/evolv3ai/vibestack-oci/releases/latest/download/kasm-only.zip) |

## 📋 What Gets Created

### VibeStack Complete (Both Servers)
- **KASM Server**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB storage)
- **Coolify Server**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB storage)
- **Total**: 4 OCPUs, 24GB RAM, 160GB storage (80% of Always Free allocation)

### Coolify Only
- **Coolify Server**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB storage)
- **Self-hosted platform** for deploying applications like Vercel/Netlify
- **Perfect for**: Developers wanting their own app deployment platform

### KASM Only
- **KASM Server**: VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB storage)
- **Remote workspaces** with full desktop environments in the browser
- **Perfect for**: Remote work, secure browsing, development environments

## 🔧 All Packages Include

- **Custom compartment** (you name it during deployment)
- **Ubuntu 22.04 LTS** (or Oracle Linux option)
- **Public networking** with security groups
- **SSH access** with your public key
- **Always Free tier compatible** - no charges

## 📖 Documentation

- [VibeStack Recommended Setup](docs/oci-vibestack-recommended-setup.md)
- [Deploy Button Specification](docs/deploy-button-specification.md)

## 🛠️ Manual Deployment

If you prefer Terraform CLI instead of the deploy buttons:

```bash
# Clone and navigate
git clone https://github.com/evolv3ai/vibestack-oci.git
cd vibestack-oci/terraform/vibestack  # or coolify-only/ or kasm-only/

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials

# Deploy
terraform init
terraform apply

# Cleanup when done
terraform destroy
```

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