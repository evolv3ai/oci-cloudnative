# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a clean VibeStack deployment repository for Oracle Cloud Infrastructure Always Free tier. It provides three deployment options for KASM Workspaces and Coolify servers, optimized for the OCI Always Free tier resources.

**Current Focus**: The repository contains three Terraform deployment packages that use a single configurable module to deploy different combinations of KASM and Coolify servers within Always Free tier limits.

### Deployment Models

- **VibeStack Full** (`deploy/full/`): Both KASM + Coolify servers (4 OCPUs, 24GB RAM, 160GB storage)
- **VibeStack Coolify** (`deploy/coolify/`): Self-hosted app platform (2 OCPUs, 12GB RAM, 100GB storage)
- **VibeStack KASM** (`deploy/kasm/`): Remote workspace server (2 OCPUs, 12GB RAM, 60GB storage)

## Architecture

### VibeStack Architecture

The repository uses a **single configurable Terraform module** that can deploy different combinations of servers based on the `deploy_kasm` and `deploy_coolify` variables:

| Resource | Specification | Purpose |
|----------|---------------|---------|
| **KASM Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB block volume) | Remote workspace hosting with KASM Workspaces |
| **Coolify Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB block volume) | Self-hosted application platform |
| **Shared Network** | VCN (10.0.0.0/16), Public Subnet (10.0.1.0/24), Internet Gateway | Network infrastructure with public access |
| **Security** | TCP ports 22/80/443/8000 + configurable KASM ports | Controlled access with SSH, HTTP(S), and application ports |

**Resource Utilization**: 4/4 OCPUs (100%), 24/24GB RAM (100%), 160/200GB storage (80%)

### Configurable Module Variables

The Terraform module uses conditional deployment based on boolean variables:

- `deploy_kasm = true/false`: Controls KASM server deployment
- `deploy_coolify = true/false`: Controls Coolify server deployment

Each package sets these variables appropriately:
- **VibeStack Full**: `deploy_kasm = true`, `deploy_coolify = true`
- **VibeStack Coolify**: `deploy_kasm = false`, `deploy_coolify = true`
- **VibeStack KASM**: `deploy_kasm = true`, `deploy_coolify = false`

## Ansible Integration

**IMPORTANT**: Ansible is automatically installed during deployment via cloud-init scripts embedded in the Terraform configuration.

### How Ansible Integration Works

1. **Terraform Deployment**: Each compute instance includes cloud-init user_data:
   ```terraform
   metadata = {
     ssh_authorized_keys = var.ssh_authorized_keys
     user_data = base64encode(file("${path.module}/cloud-init-coolify.yaml"))
   }
   ```

2. **Cloud-Init Execution**: During instance boot, cloud-init runs and:
   - Installs Python3, pip, and system dependencies
   - Installs Ansible via pip3 with proper timing delays
   - Installs Ansible collections (community.general, community.docker, ansible.posix)
   - Creates Ansible playbooks in `/opt/vibestack-ansible/`
   - Sets proper permissions for ubuntu user

3. **Post-Deployment Configuration**: After deployment, SSH into servers and run:
   ```bash
   cd /opt/vibestack-ansible
   ansible-playbook coolify/install.yml  # For Coolify server
   ansible-playbook kasm/install.yml     # For KASM server
   ```

### Current Ansible Fixes (v1.1.6)

- **Proper timing**: Added sleep delays between pip install and ansible-galaxy commands
- **Explicit paths**: Uses `/usr/local/bin/ansible-galaxy` instead of PATH resolution
- **Force installation**: Adds `--force` flag to ensure collections install correctly
- **DNS configuration**: Explicit DNS setup for reliable package downloads
- **ARM64 Docker support**: Fixed architecture mapping (aarch64 → arm64) for Docker repository

### Troubleshooting Ansible

If Ansible isn't available after deployment (older releases):
```bash
sudo pip3 install --upgrade pip
sudo pip3 install ansible
sudo pip3 install docker
sudo /usr/local/bin/ansible-galaxy collection install community.general --force
sudo /usr/local/bin/ansible-galaxy collection install community.docker --force
sudo /usr/local/bin/ansible-galaxy collection install ansible.posix --force
```

### Testing Ansible Without Full Rebuilds

For rapid Ansible development, use the test workflow:

1. **Deploy once** with Ansible disabled in cloud-init
2. **Sync changes** via rsync to running instance
3. **Test repeatedly** without destroying infrastructure
4. **See TEST_WORKFLOW.md** for detailed instructions

This avoids the slow cycle of: commit → release → deploy → test

## Release Process

**CRITICAL**: Deploy buttons in README.md pull from GitHub releases, not git tags. Follow this process:

### Creating Production Releases

1. **Make code changes** and test thoroughly
2. **Commit and push** to main branch
3. **Create GitHub release** (not just git tag):
   ```bash
   gh release create vibestack-v1.X.Y \
     --title "VibeStack v1.X.Y: Brief Description" \
     --notes "Detailed release notes here"
   ```

4. **Verify package creation**: GitHub Actions automatically builds deployment packages:
   ```bash
   gh run list --limit 3  # Check workflow status
   gh release view vibestack-v1.X.Y --json assets --jq '.assets[].name'
   ```

### Release Naming Convention

- **Format**: `vibestack-v1.X.Y` (NOT just `v1.X.Y`)
- **Examples**: `vibestack-v1.1.6`, `vibestack-v1.2.0`
- **Workflow trigger**: Only `vibestack-v*` releases trigger package building

### Deploy Button Mechanism

README.md buttons point to: `releases/latest/download/vibestack-{package}.zip`
- This automatically uses the most recent `vibestack-v*` release
- Packages are built by GitHub Actions when release is published
- Each release includes: `vibestack-full.zip`, `vibestack-coolify.zip`, `vibestack-kasm.zip`

## Development Commands

### VibeStack Terraform Deployment (Primary)

**Deploy any package:**
```bash
# Choose your deployment directory
cd deploy/full        # Both servers (VibeStack Full)
cd deploy/coolify      # Coolify only
cd deploy/kasm         # KASM only

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
- `kasm_custom_tcp_ports`: Additional ports for KASM (beyond 22/80/443)
- `coolify_custom_tcp_ports`: Additional ports for Coolify (beyond 22/80/443)

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

## Development Testing

### Ansible Testing Mode
- Use test-ansible branch for development
- Comment out auto-execution in cloud-init
- Sync files directly: rsync -avz ./ansible/ ubuntu@<IP>:/opt/vibestack-ansible/
- Test without rebuilding: terraform apply once, iterate many times

### Local Validation
```bash
# Check Ansible syntax
ansible-playbook --syntax-check ansible/kasm/install.yml

# Validate YAML
yamllint deploy/kasm/*.yaml

# Test locally with Docker (ARM64)
docker run -it --privileged ubuntu:22.04
```

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
- **Inbound ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 8000 (Coolify Web Interface)
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
deploy/
├── full/               # VibeStack Full package (KASM + Coolify)
├── coolify/            # VibeStack Coolify package (Coolify only)
├── kasm/               # VibeStack KASM package (KASM only)
└── Each contains:
    ├── *.tf            # Terraform configuration files
    ├── schema.yaml     # Resource Manager UI schema
    └── terraform.tfvars.example

scripts/
├── generate-termius-import.sh      # Generate Termius SSH import files (Bash)
├── generate-termius-import.ps1     # Generate Termius SSH import files (PowerShell)
├── manage-deployment-logs.sh       # Secure log management (Bash)
├── manage-deployment-logs.ps1      # Secure log management (PowerShell)
├── cleanup-compartment.sh          # Complete resource cleanup script
├── sync-ansible.sh                 # Quick Ansible sync for testing
└── test-csv-generation.sh          # CSV format testing utility

TEST_WORKFLOW.md                    # KASM testing workflow guide
TEST_WORKFLOW_COOLIFY.md            # Coolify testing workflow guide

docs/
├── oci-vibestack-recommended-setup.md
├── deploy-button-specification.md
├── log-management.md
└── termius-import.md

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

1. **Choose deployment**: Select `deploy/full/`, `deploy/coolify/`, or `deploy/kasm/`
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