# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a clean VibeStack deployment repository for Oracle Cloud Infrastructure Always Free tier. It provides three deployment options for KASM Workspaces and Coolify servers, optimized for the OCI Always Free tier resources.

**Current Focus**: The repository contains three Terraform deployment packages that use a single configurable module to deploy different combinations of KASM and Coolify servers within Always Free tier limits.

### Deployment Models

- **VibeStack Complete** (`terraform/vibestack/`): Both KASM + Coolify servers (4 OCPUs, 24GB RAM, 160GB storage)
- **Coolify Only** (`terraform/coolify-only/`): Self-hosted app platform (2 OCPUs, 12GB RAM, 100GB storage)
- **KASM Only** (`terraform/kasm-only/`): Remote workspace server (2 OCPUs, 12GB RAM, 60GB storage)

## Architecture

### VibeStack Architecture

The repository uses a **single configurable Terraform module** that can deploy different combinations of servers based on the `deploy_kasm` and `deploy_coolify` variables:

| Resource | Specification | Purpose |
|----------|---------------|---------|
| **KASM Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB block volume) | Remote workspace hosting with KASM Workspaces |
| **Coolify Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB block volume) | Self-hosted application platform |
| **Shared Network** | VCN (10.0.0.0/16), Public Subnet (10.0.1.0/24), Internet Gateway | Network infrastructure with public access |
| **Security** | TCP ports 22/80/443/3000 + configurable KASM ports | Controlled access with SSH, HTTP(S), and application ports |

**Resource Utilization**: 4/4 OCPUs (100%), 24/24GB RAM (100%), 160/200GB storage (80%)

### Configurable Module Variables

The Terraform module uses conditional deployment based on boolean variables:

- `deploy_kasm = true/false`: Controls KASM server deployment
- `deploy_coolify = true/false`: Controls Coolify server deployment

Each package sets these variables appropriately:
- **VibeStack Complete**: `deploy_kasm = true`, `deploy_coolify = true`
- **Coolify Only**: `deploy_kasm = false`, `deploy_coolify = true`
- **KASM Only**: `deploy_kasm = true`, `deploy_coolify = false`

## Development Commands

### VibeStack Terraform Deployment (Primary)

**Deploy any package:**
```bash
# Choose your deployment directory
cd terraform/vibestack      # Both servers
cd terraform/coolify-only   # Coolify only
cd terraform/kasm-only      # KASM only

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials and preferences

# Deploy infrastructure
terraform init
terraform apply

# Show server IPs and access information
terraform output
```

**Key Terraform variables:**
- `availability_domain`: Target AD with A1 capacity
- `assign_public_ip`: Whether to assign public IPs (default: true)
- `kasm_custom_tcp_ports`: Additional ports for KASM (beyond 22/80/443/3000)

**Destroy resources:**
```bash
# From any deployment directory
terraform destroy

# Alternative: Use the comprehensive cleanup script
./cleanup-compartment.sh <compartment_ocid>
```

### Resource Management

**Generate Termius SSH imports:**
```bash
# Create Termius-compatible import files from deployment
./generate-termius-import.sh

# For Windows users
.\generate-termius-import.ps1

# Generated files (in ./termius-import/):
# - vibestack-termius.csv     # CSV import for Termius
# - vibestack-termius.json    # JSON import for Termius
# - vibestack-ssh-config      # SSH config format
# - connect.sh/connect.ps1    # Quick connect scripts
```

**Manage deployment logs securely:**
```bash
# Save and process Terraform state logs
./manage-deployment-logs.sh <path-to-terraform-log>

# For Windows users
.\manage-deployment-logs.ps1 <path-to-terraform-log>

# Creates secure log storage and generates .env file
```

**Complete resource cleanup:**
```bash
# Delete all resources in a compartment (IRREVERSIBLE!)
./cleanup-compartment.sh <compartment_ocid>

# Examples:
./cleanup-compartment.sh ocid1.compartment.oc1..aaaaaaaae5v3sal4r6df2hrucviwerue5k3trdiln5buhh7wggjjgw2f7wua
./cleanup-compartment.sh <compartment_ocid> us-ashburn-1

# Resource deletion order (automatic):
# 1. Volume attachments → 2. Compute instances → 3. Block volumes
# 4. Boot volumes → 5. Load balancers → 6. Subnets
# 7. Internet gateways → 8. Route tables → 9. Security lists
# 10. VCNs → 11. Compartment
```

### Testing

- **Terraform validation**: `terraform plan` and `terraform validate` in any deployment directory
- **Package creation**: GitHub Actions workflow automatically creates deployment packages

## Key Configuration

### VibeStack Configuration

**Always Free Tier Constraints:**
- **OCPUs**: Must use 4/4 available Ampere A1 OCPUs (2 per server)
- **Memory**: Must use 24/24 GB available RAM (12 GB per server)
- **Storage**: Uses 160/200 GB block storage (60 GB KASM + 100 GB Coolify)
- **Region**: Resources must be deployed in your home region
- **Availability Domain**: Must target AD with A1 capacity

**Network Security:**
- **Public access**: Enabled by default for both servers
- **Inbound ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3000 (Coolify UI)
- **KASM ports**: Configurable via `kasm_custom_tcp_ports` variable
- **Outbound**: All traffic permitted for updates/packages

**Terraform Variables:**
- `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`: OCI API credentials
- `region`: Target OCI region
- `parent_compartment_ocid`: Parent compartment for new compartment creation
- `compartment_name`: Custom name for the new compartment
- `availability_domain`: Specific AD with A1 capacity
- `assign_public_ip`: Whether to assign public IPs (default: true)
- `kasm_custom_tcp_ports`: Additional TCP ports for KASM server
- `deploy_kasm`: Boolean to control KASM server deployment
- `deploy_coolify`: Boolean to control Coolify server deployment

## Repository Structure

```
terraform/
├── vibestack/          # VibeStack Complete package
├── coolify-only/       # Coolify Only package
├── kasm-only/          # KASM Only package
├── *.tf                # Shared Terraform configuration
└── schema.yaml         # Package-specific Resource Manager schema

tools/
├── generate-termius-import.sh      # Generate Termius SSH import files (Bash)
├── generate-termius-import.ps1     # Generate Termius SSH import files (PowerShell)
├── manage-deployment-logs.sh       # Secure log management (Bash)
├── manage-deployment-logs.ps1      # Secure log management (PowerShell)
├── cleanup-compartment.sh          # Complete resource cleanup script
└── test-csv-generation.sh          # CSV format testing utility

docs/
├── oci-vibestack-recommended-setup.md
└── deploy-button-specification.md

.github/workflows/
└── release-packages.yml    # Automated package creation

config/
├── .env.example            # Environment variable template
└── .gitignore             # Security-focused ignore patterns
```

## Build Process

- **GitHub Actions**: Automated workflow creates deployment packages for each release
- **Versioning**: Git tags control release versioning
- **Package Creation**: Three ZIP files created for OCI Resource Manager deployment

## Development Workflow

### VibeStack Workflow

1. **Choose deployment**: Select `terraform/vibestack/`, `terraform/coolify-only/`, or `terraform/kasm-only/`
2. **Configure Terraform**: Edit `terraform.tfvars` with OCI credentials and compartment preferences
3. **Deploy infrastructure**: Run `terraform init && terraform apply`
4. **Access servers**: Use output IPs to SSH into deployed servers
5. **Configure applications**: Set up KASM Workspaces and/or Coolify on respective servers
6. **Teardown**: Run `terraform destroy` to remove all resources

### Package Development Workflow

1. **Modify shared configuration**: Update Terraform files in any package directory
2. **Test deployment**: Validate with `terraform plan` and `terraform validate`
3. **Create release**: Push git tag to trigger automated package creation
4. **Deploy buttons**: Use generated packages with OCI Resource Manager deploy buttons

## Important Notes

- **Always Free Focus**: Clean repository dedicated to VibeStack deployments only
- **Resource Limits**: Packages respect Always Free tier limits (4 OCPUs max, 24GB RAM max)
- **Regional Constraint**: Always Free resources only available in home region
- **Capacity Issues**: A1 capacity may be limited; retry deployment or try different ADs
- **Configurable Deployments**: Single module supports three different deployment scenarios
- **Package Automation**: GitHub Actions automatically creates deployment packages for releases
- **Resource Cleanup**: Use `cleanup-compartment.sh` for comprehensive resource deletion following proper dependency order
- **Security**: All scripts include Git protection for sensitive files (.env, logs, state files)