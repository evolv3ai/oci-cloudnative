# Block Volume Mount Setup for VibeStack

This document provides the implementation plan for automatically mounting and configuring the block volume that's attached to KASM instances.

## Overview

Currently, VibeStack Terraform creates and attaches a block volume to KASM instances, but it's not automatically formatted or mounted. This leaves 100GB of allocated storage unused while the system runs on a smaller boot volume.

**Current Issue:**
- Block volume created: ✅ (via `storage.tf`)
- Block volume attached: ✅ (via `oci_core_volume_attachment`)
- Block volume mounted: ❌ **Missing**
- Docker using block volume: ❌ **Missing**

## Current State Analysis

### Terraform Configuration (Already Implemented)

**File**: `deploy/kasm/storage.tf`
```terraform
resource "oci_core_volume" "kasm_data" {
  count               = var.deploy_kasm ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = "kasm-data${local.suffix}"
  size_in_gbs         = var.kasm_block_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "kasm" {
  count           = var.deploy_kasm ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.kasm[0].id
  volume_id       = oci_core_volume.kasm_data[0].id
}
```

**Default Size**: 60GB (configurable via `kasm_block_volume_size_in_gbs`)

### What's Missing

The block volume is attached to the instance but requires:
1. **Filesystem creation** (ext4 formatting)
2. **Mount point creation** (`/mnt/kasm-data`)
3. **Auto-mount configuration** (`/etc/fstab` entry)
4. **Docker data migration** (move `/var/lib/docker` to block volume)
5. **Symlink creation** (link Docker data to new location)

## Implementation Plan

### Option 1: Cloud-Init Implementation (Recommended)

Add block volume setup to `cloud-init-kasm.yaml` in the `runcmd` section.

**Advantages:**
- ✅ Automatic setup during deployment
- ✅ No manual intervention required
- ✅ Works with ORM one-click deployment
- ✅ Consistent across all deployments

**Location**: After Ansible installation, before final message

```yaml
runcmd:
  - |
    #!/bin/bash
    # ... existing setup ...

    echo "Setting up block volume for KASM data..."
    BLOCK_DEVICE=""

    # Find the block volume device (usually sdb, but scan to be sure)
    for dev in /dev/sd{b..z}; do
      if [ -b "$dev" ] && ! mount | grep -q "$dev"; then
        # Check if device has no filesystem
        if ! sudo blkid "$dev" | grep -q TYPE; then
          BLOCK_DEVICE="$dev"
          break
        fi
      fi
    done

    if [ -n "$BLOCK_DEVICE" ]; then
      echo "Found unformatted block device: $BLOCK_DEVICE"

      # Format the block volume
      sudo mkfs.ext4 -F "$BLOCK_DEVICE"

      # Create mount point
      sudo mkdir -p /mnt/kasm-data

      # Get UUID for reliable mounting
      BLOCK_UUID=$(sudo blkid -s UUID -o value "$BLOCK_DEVICE")

      # Add to fstab for persistent mounting
      echo "UUID=$BLOCK_UUID /mnt/kasm-data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

      # Mount the volume
      sudo mount /mnt/kasm-data

      # Create Docker data directory
      sudo mkdir -p /mnt/kasm-data/docker

      # Set proper permissions
      sudo chown -R root:root /mnt/kasm-data/docker
      sudo chmod 755 /mnt/kasm-data/docker

      echo "Block volume mounted successfully at /mnt/kasm-data"
    else
      echo "No unformatted block device found - skipping block volume setup"
    fi

    # ... rest of runcmd ...
```

### Option 2: Ansible Playbook Implementation

Add a new task block to the KASM installation playbook.

**Advantages:**
- ✅ Better error handling
- ✅ Idempotent operations
- ✅ Detailed task output
- ✅ Easier to test independently

**Location**: `write_files` section in `cloud-init-kasm.yaml`, add after Docker installation tasks

```yaml
- name: Configure block volume for KASM data
  block:
    - name: Find unformatted block device
      shell: |
        for dev in /dev/sd{b..z}; do
          if [ -b "$dev" ] && ! mount | grep -q "$dev"; then
            if ! blkid "$dev" | grep -q TYPE; then
              echo "$dev"
              exit 0
            fi
          fi
        done
        exit 1
      register: block_device
      failed_when: false
      changed_when: false

    - name: Block device found
      debug:
        msg: "Found unformatted block device: {{ block_device.stdout }}"
      when: block_device.rc == 0

    - name: Format block volume
      filesystem:
        fstype: ext4
        dev: "{{ block_device.stdout }}"
        force: no
      when: block_device.rc == 0

    - name: Create mount point
      file:
        path: /mnt/kasm-data
        state: directory
        mode: '0755'
      when: block_device.rc == 0

    - name: Get block device UUID
      command: blkid -s UUID -o value {{ block_device.stdout }}
      register: block_uuid
      changed_when: false
      when: block_device.rc == 0

    - name: Add block volume to fstab
      lineinfile:
        path: /etc/fstab
        line: "UUID={{ block_uuid.stdout }} /mnt/kasm-data ext4 defaults,nofail 0 2"
        create: yes
      when: block_device.rc == 0

    - name: Mount block volume
      mount:
        path: /mnt/kasm-data
        src: "UUID={{ block_uuid.stdout }}"
        fstype: ext4
        opts: defaults,nofail
        state: mounted
      when: block_device.rc == 0

    - name: Create Docker data directory on block volume
      file:
        path: /mnt/kasm-data/docker
        state: directory
        owner: root
        group: root
        mode: '0755'
      when: block_device.rc == 0

    - name: Check if Docker is using default location
      stat:
        path: /var/lib/docker
      register: docker_default_path

    - name: Move Docker data to block volume (if needed)
      block:
        - name: Stop Docker service
          systemd:
            name: docker
            state: stopped

        - name: Move Docker data
          command: mv /var/lib/docker/* /mnt/kasm-data/docker/
          args:
            removes: /var/lib/docker
          when: docker_default_path.stat.exists

        - name: Remove old Docker directory
          file:
            path: /var/lib/docker
            state: absent

        - name: Create symlink to new Docker location
          file:
            src: /mnt/kasm-data/docker
            dest: /var/lib/docker
            state: link

        - name: Start Docker service
          systemd:
            name: docker
            state: started
      when:
        - block_device.rc == 0
        - docker_default_path.stat.exists
        - docker_default_path.stat.isdir
```

### Option 3: Hybrid Approach (Recommended)

Combine both methods for maximum reliability:

1. **Cloud-Init**: Basic volume detection and formatting
2. **Ansible**: Advanced configuration and Docker migration

This provides:
- Early volume setup (cloud-init)
- Robust configuration (Ansible)
- Fallback if either fails

## Docker Data Migration Strategy

### Pre-Docker Installation (Preferred)

If we setup the block volume **before** Docker installation, we can avoid migration:

```yaml
# In Ansible playbook, reorder tasks:
# 1. Configure block volume (new)
# 2. Create Docker data directory on block volume
# 3. Create /var/lib/docker → /mnt/kasm-data/docker symlink
# 4. Install Docker (will use block volume automatically)
```

### Post-Docker Installation (Current State)

If Docker is already installed, we need safe migration:

```yaml
- name: Migrate Docker data safely
  block:
    - name: Stop Docker and all containers
      systemd:
        name: docker
        state: stopped

    - name: Wait for Docker to fully stop
      wait_for:
        path: /var/run/docker.sock
        state: absent
        timeout: 30

    - name: Sync Docker data to block volume
      synchronize:
        src: /var/lib/docker/
        dest: /mnt/kasm-data/docker/
        archive: yes
      delegate_to: "{{ inventory_hostname }}"

    - name: Backup original Docker directory
      command: mv /var/lib/docker /var/lib/docker.bak

    - name: Create symlink
      file:
        src: /mnt/kasm-data/docker
        dest: /var/lib/docker
        state: link

    - name: Start Docker
      systemd:
        name: docker
        state: started

    - name: Verify Docker is healthy
      command: docker ps
      register: docker_verify
      retries: 3
      delay: 5
      until: docker_verify.rc == 0

    - name: Remove backup if successful
      file:
        path: /var/lib/docker.bak
        state: absent
      when: docker_verify.rc == 0
```

## Verification Steps

After implementation, verify with:

```bash
# Check block volume is mounted
df -h | grep kasm-data
# Expected: /dev/sdb mounted at /mnt/kasm-data

# Check Docker is using block volume
ls -la /var/lib/docker
# Expected: symlink to /mnt/kasm-data/docker

# Check Docker data location
sudo du -sh /mnt/kasm-data/docker
# Expected: ~10-15GB for KASM images

# Verify fstab entry
grep kasm-data /etc/fstab
# Expected: UUID=... /mnt/kasm-data ext4 defaults,nofail 0 2
```

## Rollback Plan

If block volume setup fails:

1. System continues with boot volume (existing behavior)
2. `nofail` mount option prevents boot failure
3. Docker falls back to `/var/lib/docker` if symlink fails
4. KASM installation proceeds normally

## Testing Strategy

### Phase 1: Test with Cloud-Init Only
1. Deploy fresh instance with updated cloud-init
2. Verify block volume is formatted and mounted
3. Check logs: `tail -100 /var/log/kasm-cloud-init-runcmd.log`

### Phase 2: Test with Ansible Integration
1. Run Ansible playbook independently
2. Verify Docker migration completes
3. Check KASM containers still work

### Phase 3: Full Integration Test
1. Deploy via ORM with complete setup
2. Verify end-to-end workflow
3. Test KASM workspace creation and storage

## Implementation Timeline

1. **Phase 1** (Cloud-Init): Add basic volume setup to runcmd
2. **Phase 2** (Ansible): Add advanced tasks to playbook
3. **Phase 3** (Testing): Verify with fresh ORM deployment
4. **Phase 4** (Release): Include in next VibeStack version

## Benefits

After implementation:

- ✅ **More storage**: 60GB+ available for KASM workspaces (vs 30GB currently)
- ✅ **Better performance**: Separate boot and data volumes
- ✅ **Easier scaling**: Block volume size can be increased independently
- ✅ **Cleaner separation**: System on boot, data on block volume
- ✅ **ORM ready**: Works with one-click deployment

## Files to Modify

1. **`deploy/kasm/cloud-init-kasm.yaml`**: Add runcmd block volume setup
2. **`deploy/full/cloud-init-kasm.yaml`**: Same changes (DRY - consider using module)
3. **Testing**: Deploy fresh instance and verify

## Success Criteria

- [ ] Block volume automatically formatted on first boot
- [ ] Volume mounted at `/mnt/kasm-data` persistently
- [ ] Docker data stored on block volume
- [ ] KASM installation completes successfully
- [ ] All containers run normally
- [ ] Boot volume usage stays under 50%
- [ ] Block volume shows Docker data
