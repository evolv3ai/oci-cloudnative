# VibeStack Integration Plan - Continue in New Thread

> **⚠️ IMPORTANT**: This document is for immediate use only. Delete after completing integration tasks to prevent AI confusion and repository bloat.

## 🎯 Project Goals

Transform the current `oci-cloudnative` repository into a clean, professional VibeStack deployment platform by integrating proven automation from `evolv3-ai/vibestack` repository.

### **Target Architecture:**
```
evolv3ai/oci-cloudnative (Personal - Development)    evolv3-ai/vibestack-deploy (Org - Production)
├── main branch (stable Terraform)                   ├── main branch (clean deployment only)
├── ansible-setup branch (development)               └── No development branches
│   ├── ansible/ (playbooks)
│   ├── packer/ (image building)
│   └── .github/workflows/ (CI/CD)
```

## ✅ Current Status

### **Completed:**
- ✅ Clean repository structure with `deploy/` folders (full, coolify, kasm)
- ✅ Working GitHub Actions for package creation
- ✅ Successful deploy buttons with proper naming (vibestack-full, vibestack-coolify, vibestack-kasm)
- ✅ Complete log management and Termius import system
- ✅ Resource cleanup scripts
- ✅ Analysis of existing `d:\vibestack-existing` repository

### **Key Findings from Existing Repo:**
- **Proven installation scripts** for both KASM and Coolify on OCI ARM64
- **Comprehensive environment configuration** with resource management
- **Working automation workflow** via npm scripts
- **Complete end-to-end process** from infrastructure to application setup

## 🚀 Next Steps (Priority Order)

### **Phase 1: Repository Setup**
```bash
cd D:\oci-cloudnative
git checkout -b ansible-setup
mkdir -p ansible/{kasm,coolify,common}
mkdir -p packer
mkdir -p scripts/testing
```

### **Phase 2: Extract & Convert Automation**

#### **From `d:\vibestack-existing`, extract:**

1. **KASM Installation Logic:**
   - Source: `kasm/kasm-installation.sh`
   - Key components: Docker install, KASM download/install, port config
   - Convert to: `ansible/kasm/playbook.yml`

2. **Coolify Installation Logic:**
   - Source: `coolify/coolify-installation.sh`
   - Key components: `curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash`
   - Convert to: `ansible/coolify/playbook.yml`

3. **Environment Configuration:**
   - Source: `kasm/.env.example` and `oci/.env.example`
   - Extract: Resource allocation, OCI settings, deployment types
   - Create: Ansible group_vars and host_vars

### **Phase 3: Ansible Playbook Structure**
```yaml
# ansible/kasm/playbook.yml
- name: Install KASM Workspaces on OCI ARM64
  hosts: kasm_servers
  become: yes
  vars:
    kasm_version: "1.17.0.7f020d"
    kasm_port: 8443
  tasks:
    - import_role: name=common/system_prep
    - import_role: name=common/docker
    - import_role: name=kasm/install

# ansible/coolify/playbook.yml
- name: Install Coolify on OCI ARM64
  hosts: coolify_servers
  become: yes
  tasks:
    - import_role: name=common/system_prep
    - import_role: name=common/docker
    - import_role: name=coolify/install
```

### **Phase 4: Packer Integration**
```hcl
# packer/kasm.pkr.hcl
source "oracle-oci" "kasm" {
  base_image_ocid = var.ubuntu_image_ocid
  shape          = "VM.Standard.A1.Flex"
  provisioner "ansible" {
    playbook_file = "../ansible/kasm/playbook.yml"
  }
}

# packer/coolify.pkr.hcl
source "oracle-oci" "coolify" {
  base_image_ocid = var.ubuntu_image_ocid
  shape          = "VM.Standard.A1.Flex"
  provisioner "ansible" {
    playbook_file = "../ansible/coolify/playbook.yml"
  }
}
```

### **Phase 5: CI/CD Automation**
```yaml
# .github/workflows/build-images.yml
name: Build Custom Images
on:
  push:
    branches: [ansible-setup]
    paths: ['ansible/**', 'packer/**']
jobs:
  build-and-update:
    - Run Packer to build images
    - Extract image OCIDs
    - Update Terraform variables
    - Create PR to main branch
```

### **Phase 6: Clean Deployment**
```bash
# When ready, create clean org repo
git remote add org https://github.com/evolv3-ai/vibestack-deploy.git
git push org main  # Only clean Terraform with custom image OCIDs
```

## 📋 Key Files to Reference

### **Source Files (d:\vibestack-existing):**
- `kasm/kasm-installation.sh` - Complete KASM setup process
- `coolify/coolify-installation.sh` - Complete Coolify setup process
- `kasm/.env.example` - Resource allocation and configuration
- `oci/.env.example` - OCI-specific settings
- `package.json` - Workflow automation via npm scripts

### **Target Files (to create):**
- `ansible/kasm/playbook.yml` - KASM installation playbook
- `ansible/coolify/playbook.yml` - Coolify installation playbook
- `ansible/common/roles/` - Shared setup tasks (system prep, Docker)
- `packer/kasm.pkr.hcl` - KASM image building template
- `packer/coolify.pkr.hcl` - Coolify image building template

## 🔧 Critical Implementation Notes

### **Resource Management:**
- Always Free tier: 4 OCPUs, 24GB RAM, 200GB storage total
- KASM config: 2 OCPUs, 12GB RAM, 60GB storage
- Coolify config: 2 OCPUs, 12GB RAM, 100GB storage
- Full deployment uses: 4 OCPUs, 24GB RAM, 160GB storage

### **Key Commands from Existing Repo:**
```bash
# KASM Installation Core:
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.17.0.7f020d.tar.gz
tar -xf kasm_release_1.17.0.7f020d.tar.gz
sudo bash kasm_release/install.sh

# Coolify Installation Core:
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
```

### **Validation Strategy:**
1. Test Ansible playbooks on fresh Ubuntu 22.04 instances
2. Build images with Packer
3. Deploy using custom images
4. Verify applications are accessible and functional

## 🗂️ Repository Organization

### **Personal Repo (evolv3ai/oci-cloudnative):**
- `main` branch: Stable Terraform for deployment
- `ansible-setup` branch: All automation development
- Keep messy development, testing, troubleshooting

### **Org Repo (evolv3-ai/vibestack-deploy):**
- `main` branch only: Clean Terraform with custom image OCIDs
- Professional appearance for public users
- Deploy buttons pointing to pre-built, tested images

## ⚡ Immediate Action Items

1. **Create ansible-setup branch** in current repo
2. **Extract core installation logic** from bash scripts
3. **Convert to Ansible playbooks** with proper structure
4. **Test playbooks** on fresh OCI instances
5. **Create Packer templates** for automated image building
6. **Set up CI/CD pipeline** for automated builds
7. **Update Terraform** to use custom image OCIDs
8. **Create clean org repo** for public deployment

## 🎯 Success Criteria

- ✅ One-click deployments using pre-configured images
- ✅ Clean separation between development and production repos
- ✅ Automated image building and testing
- ✅ Professional deploy buttons for public use
- ✅ Maintainable automation using industry-standard tools (Ansible, Packer)

---

**🗑️ DELETE THIS FILE after integration is complete to prevent repository bloat and AI confusion.**