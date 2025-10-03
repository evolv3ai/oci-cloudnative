# Recommended Improvements Specification for VibeStack KASM Deployment

**Created**: 2025-09-30
**Status**: Planned - Ready for Implementation
**Target Release**: v1.2.0

---

## Context for Implementation

This specification outlines improvements to VibeStack's KASM deployment based on analysis of two official Kasm repositories:

1. **kasmweb/oci** (oci-kasm) - Official OCI Terraform deployment with integrated DNS, Let's Encrypt, and bootstrap installation
2. **kasmweb/ansible** (kasm-ansible) - Official Ansible deployment for multi-server production environments

**Analysis Date**: 2025-09-30
**Repositories Analyzed**:
- Local clone: `/home/kasm-user/dv/projects/oci-kasm/oci/single_server/`
- Local clone: `/home/kasm-user/dv/projects/kasm-ansible/`

**Current VibeStack Implementation**:
- File: `/home/kasm-user/dv/projects/oci-cloudnative/deploy/kasm/cloud-init-kasm.yaml`
- Approach: Single-server Always Free tier deployment with Ansible playbook embedded in cloud-init
- Target: OCI ARM64 (VM.Standard.A1.Flex) instances

---

## Executive Summary

VibeStack's KASM deployment is **fundamentally sound** but can be improved with battle-tested patterns from official Kasm repositories. The key insight: **Keep VibeStack's automation-first approach while adopting proven reliability patterns**.

**What to Keep**:
- ✅ Cloud-init embedded Ansible (no external controller needed)
- ✅ Automated KASM installer downloads from S3
- ✅ Single-server all-in-one design for Always Free tier
- ✅ Credential file output (`/opt/kasm/credentials.txt`)
- ✅ Health check monitoring script

**What to Improve**:
- ⚠️ Swap management (add intelligent differential calculation)
- ⚠️ Installation reliability (add retry logic for APT locks)
- ⚠️ Idempotency (allow safe re-runs)
- ⚠️ Input validation (add Terraform variable validation)

---

## Priority 1: Critical Reliability Improvements

### 1.1 APT Lock Retry Logic

**Problem**: Cloud-init often has parallel apt operations causing lock conflicts. KASM installation fails unpredictably with "Failed to lock apt for exclusive operation" errors.

**Solution**: Add retry logic to KASM installation tasks.

**Reference**: `kasm-ansible/roles/install_common/tasks/agent_install.yml:23-27`

**Implementation Location**: `deploy/kasm/cloud-init-kasm.yaml:249-270`

**Changes Required**:

```yaml
# Current (lines 249-260)
- name: Run KASM offline installation for ARM64
  shell: |
    cd /tmp/kasm_install/kasm_release
    ./install.sh --accept-eula --swap-size {{ swap_size }} \
      --admin-password "{{ kasm_admin_password }}" \
      --user-password "{{ kasm_user_password }}" \
      --offline-workspaces /tmp/kasm_install/kasm_release_workspace_images.tar.gz \
      --offline-service /tmp/kasm_install/kasm_release_service_images.tar.gz \
      --offline-network-plugin /tmp/kasm_install/kasm_release_plugin_images.tar.gz
  args:
    creates: /opt/kasm/current
  when: docker_arch == 'arm64'

# Improved (add retry logic)
- name: Run KASM offline installation for ARM64
  shell: |
    cd /tmp/kasm_install/kasm_release
    ./install.sh --accept-eula --swap-size {{ swap_size }} \
      --admin-password "{{ kasm_admin_password }}" \
      --user-password "{{ kasm_user_password }}" \
      --offline-workspaces /tmp/kasm_install/kasm_release_workspace_images.tar.gz \
      --offline-service /tmp/kasm_install/kasm_release_service_images.tar.gz \
      --offline-network-plugin /tmp/kasm_install/kasm_release_plugin_images.tar.gz
  args:
    creates: /opt/kasm/current
  register: install_result
  retries: 20
  delay: 10
  until: >
    install_result is success or
    ('Failed to lock apt for exclusive operation' not in (install_result.stderr | default('')) and
     '/var/lib/dpkg/lock' not in (install_result.stderr | default('')))
  when: docker_arch == 'arm64'
```

**Apply to**:
- ARM64 installation task (line 249)
- AMD64 installation task (line 262)

**Testing**: Deploy and verify recovery from simulated APT lock by running `apt update` in parallel during installation.

---

### 1.2 Idempotency Checks

**Problem**: Re-running the playbook fails or causes issues if KASM is already installed. No graceful handling of existing installations.

**Solution**: Check if KASM exists before attempting installation tasks.

**Reference**: `kasm-ansible/roles/install_common/tasks/main.yml:4-10`

**Implementation Location**: `deploy/kasm/cloud-init-kasm.yaml:208` (before "Download and install KASM Workspaces")

**Changes Required**:

```yaml
# Add before line 208 (before "Download and install KASM Workspaces")
- name: Check if KASM is already installed
  stat:
    path: /opt/kasm/current
  register: kasm_installed_check

- name: Skip installation if already present
  debug:
    msg: "✅ KASM already installed at /opt/kasm/current - skipping installation"
  when: kasm_installed_check.stat.exists

# Then wrap the entire "Download and install KASM Workspaces" block
- name: Download and install KASM Workspaces (Offline Method)
  when: not kasm_installed_check.stat.exists  # Add this condition
  block:
    # ... all existing installation tasks (lines 208-296)
```

**Benefits**:
- Allows safe re-runs for testing
- Supports incremental updates
- Matches official Ansible pattern

**Testing**: Run playbook twice; second run should skip installation cleanly.

---

## Priority 2: Swap Management Improvements

### 2.1 Intelligent Differential Swap Calculation

**Problem**: Current implementation has no swap configuration. Always Free tier instances may already have some swap. Creating fixed-size swap wastes limited disk space.

**Solution**: Calculate existing swap, determine needed additional swap, only create differential.

**Reference**:
- `kasm-ansible/roles/install_common/tasks/main.yml:44-70`
- `kasm-ansible/roles/install_common/tasks/mkswap.yml:1-26`

**Implementation Location**: `deploy/kasm/cloud-init-kasm.yaml:70-100` (replace current swap block)

**Changes Required**:

```yaml
# Replace existing swap configuration block (lines 70-100)
- name: Configure swap space
  block:
    - name: Get current swap size in bytes
      shell: cat /proc/meminfo | grep SwapTotal | awk '{print $2 * 1024}'
      register: current_swap_size
      changed_when: false

    - name: Calculate desired swap in bytes
      set_fact:
        desired_swap_bytes: "{{ (swap_size | regex_replace('G$', '') | int * 1024 * 1024 * 1024) | int }}"
        current_swap_bytes: "{{ current_swap_size.stdout | int }}"

    - name: Calculate differential swap needed
      set_fact:
        new_swap_size: "{{ [0, (desired_swap_bytes | int - current_swap_bytes | int)] | max }}"

    - name: Display swap calculation
      debug:
        msg:
          - "Current swap: {{ (current_swap_bytes | int / 1024 / 1024 / 1024) | round(2) }}GB"
          - "Desired swap: {{ (desired_swap_bytes | int / 1024 / 1024 / 1024) | round(2) }}GB"
          - "Additional needed: {{ (new_swap_size | int / 1024 / 1024 / 1024) | round(2) }}GB"

    - name: Check if swap file exists
      stat:
        path: "{{ swap_file }}"
      register: swap_file_stat

    - name: Create swap file using dd (avoids sparse files)
      command: dd if=/dev/zero bs=1M count={{ (new_swap_size | int / 1024 / 1024) | int }} of={{ swap_file }}
      when:
        - not swap_file_stat.stat.exists
        - new_swap_size | int > 0

    - name: Set swap file permissions
      file:
        path: "{{ swap_file }}"
        mode: '0600'
      when:
        - not swap_file_stat.stat.exists
        - new_swap_size | int > 0

    - name: Make swap file
      command: mkswap {{ swap_file }}
      when:
        - not swap_file_stat.stat.exists
        - new_swap_size | int > 0

    - name: Enable swap
      command: swapon {{ swap_file }}
      when:
        - not swap_file_stat.stat.exists
        - new_swap_size | int > 0

    - name: Add swap to fstab
      lineinfile:
        path: /etc/fstab
        line: "{{ swap_file }} none swap sw 0 0"
        create: yes
      when:
        - not swap_file_stat.stat.exists
        - new_swap_size | int > 0
```

**Key Changes**:
1. Uses `dd` instead of `fallocate` (avoids "files with holes" error)
2. Calculates only needed additional swap
3. Skips swap creation if sufficient swap exists
4. Uses `/swapfile` (standard location) instead of `/var/kasm.swap`

**Testing**:
- Test on instance with no swap (should create 2GB)
- Test on instance with 1GB swap (should create 1GB additional)
- Test on instance with 2GB+ swap (should skip creation)

---

## Priority 3: Terraform Variable Validation

### 3.1 Enhanced Input Validation

**Problem**: Terraform variables have minimal validation. Invalid inputs cause cryptic deployment errors.

**Solution**: Add regex validation patterns from official oci-kasm repository.

**Reference**: `oci-kasm/oci/single_server/variables.tf:5-221`

**Implementation Location**: `deploy/kasm/variables.tf`

**Changes Required**:

```hcl
# Add to existing variables in deploy/kasm/variables.tf

variable "tenancy_ocid" {
  description = "OCID of the tenancy where resources will be created."
  type        = string

  # Add validation
  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.oc1\\.+[a-z0-9]{60}$", var.tenancy_ocid))
    error_message = "The tenancy_ocid must be a valid Oracle Cloud Tenancy OCID value (e.g. ocid1.tenancy.oc1..aaaaaaaaba3pv6wkcr4jqae5f44n2b2m2yt2j6rx32uzr4h25vqstifsfdsq)."
  }
}

variable "region" {
  description = "OCI region identifier (for example, us-phoenix-1)."
  type        = string

  # Add validation
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]{5,}-[0-9]{1}$", var.region))
    error_message = "The region must be a valid Oracle Cloud (OCI) Region name (e.g. us-ashburn-1, us-phoenix-1, uk-london-1)."
  }
}

variable "fingerprint" {
  description = "API signing key fingerprint. Leave blank when using the OCI Cloud Shell or Resource Manager."
  type        = string
  default     = ""

  # Add validation
  validation {
    condition     = var.fingerprint == "" || can(regex("^([a-f0-9]{2}:?){16}$", var.fingerprint))
    error_message = "The API fingerprint must be 16 colon-delimited hex bytes (e.g. 12:34:56:78:90:ab:cd:ef:12:34:56:78:90:ab:cd:ef) or left blank for ORM/Cloud Shell."
  }
}

variable "compartment_name" {
  description = "Name for the new compartment that will contain all VibeStack resources."
  type        = string
  default     = "vibestack"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,99}$", var.compartment_name))
    error_message = "Compartment name must start with a letter and can only contain letters, numbers, hyphens, and underscores. Maximum 100 characters."
  }
}

# Enhance existing SSH key validation
variable "ssh_authorized_keys" {
  description = "One or more SSH public keys that should be added to the compute instances."
  type        = string

  validation {
    condition = can(regex("^(ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ssh-ed25519 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp256 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp384 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp521 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?)$", var.ssh_authorized_keys))
    error_message = "SSH public key must be in valid OpenSSH format (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*). Example: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbPhiQgg... user@hostname'"
  }
}
```

**Apply to all three packages**:
- `deploy/full/variables.tf`
- `deploy/kasm/variables.tf`
- `deploy/coolify/variables.tf`

**Benefits**:
- Clear error messages at `terraform plan` stage
- Prevents wasted deployment time
- Better user experience

**Testing**: Test with invalid inputs to verify error messages are helpful.

---

## Priority 4: CIDR-Based Security Lists (Optional)

### 4.1 Configurable Access Control

**Problem**: Security lists default to `0.0.0.0/0` for all traffic. Not suitable for production environments.

**Solution**: Add optional CIDR filtering for SSH and web access.

**Reference**: `oci-kasm/oci/single_server/module/security_list.tf:12-22`

**Implementation Location**:
- `deploy/kasm/variables.tf` (new variables)
- `deploy/kasm/network.tf` (security list changes)

**Changes Required**:

```hcl
# Add to variables.tf
variable "allow_ssh_cidrs" {
  description = "CIDR ranges allowed to SSH to servers. Use 0.0.0.0/0 for unrestricted (not recommended for production)."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for subnet in var.allow_ssh_cidrs : can(cidrhost(subnet, 0))])
    error_message = "One of the subnets provided in allow_ssh_cidrs is not a valid CIDR range."
  }
}

variable "allow_web_cidrs" {
  description = "CIDR ranges allowed to access web interfaces (HTTP/HTTPS). Use 0.0.0.0/0 for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for subnet in var.allow_web_cidrs : can(cidrhost(subnet, 0))])
    error_message = "One of the subnets provided in allow_web_cidrs is not a valid CIDR range."
  }
}
```

```hcl
# Modify network.tf security list
resource "oci_core_security_list" "public" {
  compartment_id = oci_identity_compartment.vibestack.id
  display_name   = local.security_list_name
  vcn_id         = oci_core_virtual_network.free_tier.id

  # SSH access - CIDR-filtered
  dynamic "ingress_security_rules" {
    for_each = var.allow_ssh_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      description = "SSH access"
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # Web access (HTTP/HTTPS) - CIDR-filtered
  dynamic "ingress_security_rules" {
    for_each = var.allow_web_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      description = "Web access (HTTP/HTTPS)"
      tcp_options {
        min = 80
        max = 80
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.allow_web_cidrs
    content {
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      description = "Web access (HTTPS)"
      tcp_options {
        min = 443
        max = 443
      }
    }
  }

  # Keep existing dynamic rules for custom ports
  dynamic "ingress_security_rules" {
    for_each = local.ingress_tcp_ports
    content {
      protocol    = "6"
      source      = "0.0.0.0/0"  # Custom ports remain open
      source_type = "CIDR_BLOCK"
      description = ingress_security_rules.value.description
      tcp_options {
        min = ingress_security_rules.value.port
        max = ingress_security_rules.value.port
      }
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "Allow all outbound traffic"
  }
}
```

**Backwards Compatibility**: Default `["0.0.0.0/0"]` maintains current behavior.

**Testing**:
- Test with restrictive CIDR (only your IP)
- Test with multiple CIDRs
- Verify default `0.0.0.0/0` still works

---

## What NOT to Adopt

### Do Not Change: Core Architecture

**Official kasm-ansible uses**:
- Multi-server role-based deployments (separate db/web/agent/guac/proxy)
- External Ansible controller
- Manual file uploads to `roles/install_common/files/`
- Inventory file credential management
- Zone-based scaling architecture

**Why not adopt**:
- VibeStack targets Always Free tier **single-server** deployments
- Cloud-init embedded approach is superior for OCI automation
- No need for multi-zone scaling complexity
- Automated downloads better than manual file management

**Keep VibeStack's approach**: Cloud-init + single playbook + automated downloads

---

### Do Not Change: Installation Method

**Official oci-kasm uses**:
- Bootstrap script in cloud-init user_data (templatefile)
- KASM installed during instance boot
- Let's Encrypt certificates via Terraform ACME provider
- OCI DNS zone integration

**Why not adopt**:
- Ansible playbook post-deployment is more flexible
- Separates infrastructure from application concerns
- Faster testing/iteration (matches TEST_WORKFLOW.md)
- Simpler for Always Free tier users (no DNS zone required)

**Keep VibeStack's approach**: Terraform for infra, Ansible for KASM installation

---

## Implementation Plan

### Phase 1: Critical Reliability (Target: v1.2.0)

**Files to modify**:
- `deploy/kasm/cloud-init-kasm.yaml`
- `deploy/full/cloud-init-kasm.yaml` (if different)

**Tasks**:
1. ✅ Add idempotency checks (section 1.2)
2. ✅ Add APT lock retry logic (section 1.1)
3. ✅ Test deployment twice (verify idempotency)
4. ✅ Test with simulated APT conflicts

**Success Criteria**:
- Playbook can run twice without errors
- APT lock conflicts auto-recover
- No behavioral changes for successful first-run

---

### Phase 2: Swap Management (Target: v1.2.0)

**Files to modify**:
- `deploy/kasm/cloud-init-kasm.yaml` (lines 70-100)
- `deploy/full/cloud-init-kasm.yaml` (if applicable)

**Tasks**:
1. ✅ Implement differential swap calculation (section 2.1)
2. ✅ Change to `dd` method (avoid fallocate)
3. ✅ Test on instances with varying existing swap
4. ✅ Update CLAUDE.md with swap changes

**Success Criteria**:
- Correct swap calculation on all test cases
- No duplicate swap creation
- Efficient disk space usage

---

### Phase 3: Input Validation (Target: v1.2.1)

**Files to modify**:
- `deploy/kasm/variables.tf`
- `deploy/coolify/variables.tf`
- `deploy/full/variables.tf`

**Tasks**:
1. ✅ Add regex validations (section 3.1)
2. ✅ Test with invalid inputs
3. ✅ Verify error messages are clear
4. ✅ Update schema.yaml if needed for ORM

**Success Criteria**:
- Clear error messages at plan stage
- No breaking changes to valid inputs
- Better user experience

---

### Phase 4: Optional CIDR Security (Target: v1.3.0)

**Files to modify**:
- `deploy/kasm/variables.tf`
- `deploy/kasm/network.tf`
- `deploy/kasm/schema.yaml` (ORM UI)
- Apply to coolify and full packages

**Tasks**:
1. ✅ Add CIDR variables with validation
2. ✅ Modify security lists to use dynamic blocks
3. ✅ Test with restricted and open access
4. ✅ Update documentation

**Success Criteria**:
- Backwards compatible (default 0.0.0.0/0)
- CIDR filtering works correctly
- ORM UI presents options clearly

---

## Testing Strategy

### Unit Tests
- Terraform validate on all packages
- Variable validation with invalid inputs
- Schema.yaml validation for ORM

### Integration Tests
1. **Fresh deployment** (no existing KASM, no existing swap)
   - Should create swap, install KASM, complete successfully

2. **Re-run deployment** (KASM exists)
   - Should skip KASM installation gracefully

3. **Partial swap deployment** (instance has 1GB swap, needs 2GB)
   - Should create 1GB additional swap only

4. **APT lock scenario** (simulate with parallel apt update)
   - Should retry and succeed

### Regression Tests
- Verify existing deployments still work
- Verify ORM deploy buttons function
- Verify Coolify package unaffected

---

## Documentation Updates

### Files to Update
- `CLAUDE.md` - Add swap management section
- `README.md` - Update feature list
- `TEST_WORKFLOW.md` - Note idempotency testing
- Release notes for v1.2.0

### New Documentation
- None required (this spec serves as implementation reference)

---

## Compatibility Notes

### Backwards Compatibility
- ✅ All changes are backwards compatible
- ✅ Default values maintain current behavior
- ✅ Optional variables don't affect existing deployments
- ✅ Idempotency checks gracefully handle existing installs

### Breaking Changes
- ❌ None

### Migration Required
- ❌ None - improvements apply to new deployments

---

## Success Metrics

### Reliability
- 📊 Reduce failed deployments due to APT locks: Target 0%
- 📊 Support safe re-runs without errors: 100%

### User Experience
- 📊 Clearer error messages at validation stage
- 📊 More efficient resource usage (intelligent swap)
- 📊 Optional security hardening (CIDR filtering)

### Development Velocity
- 📊 Faster testing with idempotent playbooks
- 📊 Easier debugging with retry logic
- 📊 Better alignment with official Kasm patterns

---

## References

### Source Repositories Analyzed
1. **kasmweb/oci** - Official OCI Terraform
   - Location: `/home/kasm-user/dv/projects/oci-kasm/oci/single_server/`
   - Key files: `variables.tf`, `module/instance.tf`, `module/letsencrypt.tf`

2. **kasmweb/ansible** - Official Ansible deployment
   - Location: `/home/kasm-user/dv/projects/kasm-ansible/`
   - Key files: `roles/install_common/tasks/main.yml`, `mkswap.yml`, `agent_install.yml`

### Current VibeStack Files
- `deploy/kasm/cloud-init-kasm.yaml` - Main KASM playbook
- `deploy/kasm/variables.tf` - Terraform variables
- `deploy/kasm/network.tf` - Network and security lists
- `CLAUDE.md` - Project documentation

### Related Documentation
- OCI Always Free Tier: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm
- KASM Installation Guide: https://www.kasmweb.com/docs/latest/install.html
- Ansible Best Practices: https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html

---

## Implementation Context

When implementing these changes:

1. **Read this spec completely first** - Understand the why, not just the what
2. **Review the reference files** - See the official patterns in context
3. **Test incrementally** - Implement Priority 1, test, then Priority 2, test, etc.
4. **Maintain VibeStack philosophy** - Automation-first, Always Free tier focused, simple
5. **Document changes** - Update CLAUDE.md and release notes
6. **Consider Coolify** - Some improvements may apply to coolify package too

The goal is not to copy the official repos, but to adopt their proven reliability patterns while maintaining VibeStack's unique value: **automated single-server deployment optimized for OCI Always Free tier**.

---

**End of Specification**
