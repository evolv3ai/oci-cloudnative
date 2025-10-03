# Cloudflare Tunnel Integration Plan for KASM

This document analyzes the existing Cloudflare tunnel integration from `oci-kasm-cloudflare` scripts and provides a plan to integrate missing features into the VibeStack Terraform/Ansible deployment.

## Executive Summary

**Goal**: Enable optional Cloudflare Tunnel support for KASM deployments, similar to the existing Coolify implementation.

**Status**: Coolify package already has Cloudflare tunnel support. KASM package needs similar integration.

**Approach**: Leverage existing patterns from Coolify deployment + logic from standalone scripts.

## Current State Analysis

### What We Have

#### 1. Standalone Scripts (`/home/kasm-user/dv/projects/_admin/scripts/oci-kasm-cloudflare/`)

**Files**:
- `cloudflare-tunnel-setup.sh` - Tunnel creation and DNS configuration
- `kasm-installation.sh` - KASM installation with block volume support
- `oci-infrastructure-setup.sh` - OCI infrastructure deployment
- `fix-dns.sh` - DNS troubleshooting utilities

**Features**:
- ✅ Cloudflare tunnel creation via API
- ✅ DNS CNAME record automation
- ✅ Tunnel credentials management
- ✅ Systemd service configuration
- ✅ Block volume setup and Docker migration
- ✅ UFW firewall configuration

#### 2. Coolify Terraform Package (`deploy/coolify/`)

**Variables** (from `variables.tf`):
```terraform
variable "enable_cloudflare_tunnel" {
  description = "Enable Cloudflare tunnel for secure access to Coolify"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in dashboard right sidebar)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain (found in domain dashboard)"
  type        = string
  default     = ""
}

variable "tunnel_hostname" {
  description = "Hostname for Coolify access (e.g., coolify.yourdomain.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.tunnel_hostname == "" || can(regex("^[a-z0-9-]+\\.[a-z0-9.-]+\\.[a-z]{2,}$", var.tunnel_hostname))
    error_message = "Tunnel hostname must be a valid domain format (e.g., coolify.yourdomain.com)."
  }
}

variable "ssh_hostname" {
  description = "Hostname for SSH access (e.g., ssh.yourdomain.com). Leave empty to auto-generate from tunnel_hostname"
  type        = string
  default     = ""
}
```

**Integration Pattern**: Cloud-init based implementation with conditional execution.

### What's Missing in KASM Package

Comparing KASM package to Coolify:

| Feature | Coolify | KASM | Priority |
|---------|---------|------|----------|
| Cloudflare tunnel variables | ✅ | ❌ | High |
| Tunnel setup in cloud-init | ✅ | ❌ | High |
| DNS automation | ✅ | ❌ | High |
| Tunnel credentials management | ✅ | ❌ | High |
| Systemd service | ✅ | ❌ | High |
| Block volume auto-mount | ⚠️ Partial | ❌ | High |
| UFW firewall rules | ⚠️ Basic | ⚠️ Basic | Medium |
| SSH tunnel hostname | ✅ | ❌ | Low |

## Integration Plan

### Phase 1: Add Terraform Variables (KASM Package)

**File**: `deploy/kasm/variables.tf`

Add after line 132 (after `deploy_coolify` variable):

```terraform
# =============================================================================
# CLOUDFLARE TUNNEL CONFIGURATION (Optional)
# =============================================================================

variable "enable_cloudflare_tunnel" {
  description = "Enable Cloudflare tunnel for secure access to KASM Workspaces"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in dashboard right sidebar)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain (found in domain dashboard)"
  type        = string
  default     = ""
}

variable "tunnel_hostname" {
  description = "Hostname for KASM access (e.g., kasm.yourdomain.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.tunnel_hostname == "" || can(regex("^[a-z0-9-]+\\.[a-z0-9.-]+\\.[a-z]{2,}$", var.tunnel_hostname))
    error_message = "Tunnel hostname must be a valid domain format (e.g., kasm.yourdomain.com)."
  }
}

variable "kasm_port" {
  description = "KASM Workspaces web interface port"
  type        = number
  default     = 443
}
```

### Phase 2: Update Outputs (KASM Package)

**File**: `deploy/kasm/outputs.tf`

Add Cloudflare-specific outputs:

```terraform
output "cloudflare_tunnel_status" {
  description = "Cloudflare Tunnel configuration status"
  value = var.enable_cloudflare_tunnel ? {
    enabled        = true
    hostname       = var.tunnel_hostname
    access_url     = "https://${var.tunnel_hostname}"
    setup_complete = "Tunnel will be configured during cloud-init"
  } : {
    enabled = false
    message = "Cloudflare Tunnel is disabled. Access KASM via public IP."
  }
}

output "cloudflare_tunnel_instructions" {
  description = "Instructions for Cloudflare Tunnel setup"
  value = var.enable_cloudflare_tunnel ? <<-EOT

    Cloudflare Tunnel Setup:
    ========================
    The tunnel is being automatically configured during instance startup.

    Monitor setup progress:
      ssh -i ${var.private_key_path} ubuntu@${oci_core_instance.kasm[0].public_ip} 'tail -f /var/log/kasm-cloud-init-runcmd.log'

    Check tunnel status:
      ssh -i ${var.private_key_path} ubuntu@${oci_core_instance.kasm[0].public_ip} 'sudo systemctl status cloudflared-kasm-tunnel'

    Access KASM:
      https://${var.tunnel_hostname}

    If tunnel setup fails, check logs:
      ssh -i ${var.private_key_path} ubuntu@${oci_core_instance.kasm[0].public_ip} 'sudo journalctl -u cloudflared-kasm-tunnel -n 50'

  EOT : "Cloudflare Tunnel is not enabled."
}
```

### Phase 3: Update Cloud-Init (KASM Package)

**File**: `deploy/kasm/cloud-init-kasm.yaml`

Add Cloudflare tunnel configuration to `write_files` section:

```yaml
  - path: /opt/vibestack/kasm/cloudflare-tunnel-setup.sh
    content: |
      #!/bin/bash
      # Cloudflare Tunnel Setup for KASM Workspaces
      # Automatically configures Cloudflare Tunnel if enabled

      set -e

      # Configuration from Terraform variables
      TUNNEL_ENABLED="${enable_cloudflare_tunnel}"
      CF_API_TOKEN="${cloudflare_api_token}"
      CF_ACCOUNT_ID="${cloudflare_account_id}"
      CF_ZONE_ID="${cloudflare_zone_id}"
      TUNNEL_HOSTNAME="${tunnel_hostname}"
      KASM_PORT="${kasm_port}"
      TUNNEL_NAME="kasm-tunnel-$(hostname -s)"

      if [ "$TUNNEL_ENABLED" != "true" ]; then
        echo "Cloudflare Tunnel is disabled - skipping setup"
        exit 0
      fi

      echo "🚀 Setting up Cloudflare Tunnel for KASM..."

      # Validate required variables
      if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ACCOUNT_ID" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$TUNNEL_HOSTNAME" ]; then
        echo "❌ Missing required Cloudflare configuration"
        echo "Required: cloudflare_api_token, cloudflare_account_id, cloudflare_zone_id, tunnel_hostname"
        exit 1
      fi

      # Install cloudflared
      echo "📦 Installing cloudflared..."
      curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
      chmod +x /usr/local/bin/cloudflared

      # Create tunnel
      echo "🔧 Creating Cloudflare Tunnel..."
      TUNNEL_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"name\":\"$TUNNEL_NAME\",\"config_src\":\"cloudflare\"}")

      TUNNEL_ID=$(echo "$TUNNEL_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

      if [ -z "$TUNNEL_ID" ]; then
        # Try to get existing tunnel
        EXISTING_TUNNEL=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel?name=$TUNNEL_NAME" \
          -H "Authorization: Bearer $CF_API_TOKEN")
        TUNNEL_ID=$(echo "$EXISTING_TUNNEL" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -z "$TUNNEL_ID" ]; then
          echo "❌ Failed to create or find tunnel"
          exit 1
        fi
        echo "✅ Using existing tunnel: $TUNNEL_ID"
      else
        echo "✅ Tunnel created: $TUNNEL_ID"
      fi

      # Get tunnel credentials
      echo "🔐 Getting tunnel credentials..."
      CREDS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
        -H "Authorization: Bearer $CF_API_TOKEN")

      TUNNEL_TOKEN=$(echo "$CREDS_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

      if [ -z "$TUNNEL_TOKEN" ]; then
        echo "❌ Failed to get tunnel token"
        exit 1
      fi

      # Create tunnel config directory
      mkdir -p /etc/cloudflared

      # Write tunnel credentials
      cat > /etc/cloudflared/credentials.json <<EOF
      {
        "AccountTag": "$CF_ACCOUNT_ID",
        "TunnelID": "$TUNNEL_ID",
        "TunnelSecret": "$TUNNEL_TOKEN"
      }
      EOF

      chmod 600 /etc/cloudflared/credentials.json

      # Create tunnel configuration
      cat > /etc/cloudflared/config.yml <<EOF
      tunnel: $TUNNEL_ID
      credentials-file: /etc/cloudflared/credentials.json

      ingress:
        - hostname: $TUNNEL_HOSTNAME
          service: https://localhost:$KASM_PORT
          originRequest:
            noTLSVerify: true
            connectTimeout: 30s
            tlsTimeout: 30s
            tcpKeepAlive: 30s
            keepAliveConnections: 10
            keepAliveTimeout: 90s
        - service: http_status:404
      EOF

      # Create DNS CNAME record
      echo "🌐 Creating DNS record..."
      HOSTNAME_PART=$(echo "$TUNNEL_HOSTNAME" | cut -d'.' -f1)
      TUNNEL_DOMAIN_TARGET="$TUNNEL_ID.cfargotunnel.com"

      DNS_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"CNAME\",\"name\":\"$HOSTNAME_PART\",\"content\":\"$TUNNEL_DOMAIN_TARGET\",\"proxied\":true}")

      echo "✅ DNS record created: $TUNNEL_HOSTNAME -> $TUNNEL_DOMAIN_TARGET"

      # Create systemd service
      echo "⚙️ Creating systemd service..."
      cat > /etc/systemd/system/cloudflared-kasm-tunnel.service <<EOF
      [Unit]
      Description=Cloudflare Tunnel for KASM Workspaces
      After=network.target

      [Service]
      Type=simple
      User=root
      ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
      Restart=on-failure
      RestartSec=10s

      [Install]
      WantedBy=multi-user.target
      EOF

      # Enable and start service
      systemctl daemon-reload
      systemctl enable cloudflared-kasm-tunnel
      systemctl start cloudflared-kasm-tunnel

      echo "✅ Cloudflare Tunnel setup complete!"
      echo "   Access KASM at: https://$TUNNEL_HOSTNAME"
      echo "   Tunnel ID: $TUNNEL_ID"

      # Save tunnel info
      cat > /opt/kasm/cloudflare-tunnel-info.txt <<EOF
      Cloudflare Tunnel Information
      =============================
      Tunnel ID: $TUNNEL_ID
      Tunnel Name: $TUNNEL_NAME
      Hostname: $TUNNEL_HOSTNAME
      Target: $TUNNEL_DOMAIN_TARGET

      Service Status: sudo systemctl status cloudflared-kasm-tunnel
      View Logs: sudo journalctl -u cloudflared-kasm-tunnel -f
      EOF

      chmod 600 /opt/kasm/cloudflare-tunnel-info.txt
    permissions: '0755'
```

Add to `runcmd` section (after Ansible setup):

```yaml
runcmd:
  - |
    #!/bin/bash
    # ... existing setup ...

    # Setup Cloudflare Tunnel if enabled
    if [ "${enable_cloudflare_tunnel}" = "true" ]; then
      echo "Setting up Cloudflare Tunnel..."
      /opt/vibestack/kasm/cloudflare-tunnel-setup.sh || echo "Cloudflare Tunnel setup failed - check logs"
    else
      echo "Cloudflare Tunnel is disabled"
    fi

    # ... rest of runcmd ...
```

### Phase 4: Update Schema (for ORM UI)

**File**: `deploy/kasm/schema.yaml`

Add Cloudflare Tunnel section:

```yaml
- title: "Cloudflare Tunnel Configuration (Optional)"
  variables:
    - enable_cloudflare_tunnel
    - cloudflare_api_token
    - cloudflare_account_id
    - cloudflare_zone_id
    - tunnel_hostname

enable_cloudflare_tunnel:
  type: boolean
  title: "Enable Cloudflare Tunnel"
  description: "Enable secure access via Cloudflare Tunnel (no open inbound ports required)"
  default: false

cloudflare_api_token:
  type: password
  title: "Cloudflare API Token"
  description: "API token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions"
  required: false
  visible:
    eq:
      - enable_cloudflare_tunnel
      - true

cloudflare_account_id:
  type: string
  title: "Cloudflare Account ID"
  description: "Found in Cloudflare dashboard right sidebar"
  required: false
  visible:
    eq:
      - enable_cloudflare_tunnel
      - true

cloudflare_zone_id:
  type: string
  title: "Cloudflare Zone ID"
  description: "Found in your domain's Cloudflare dashboard"
  required: false
  visible:
    eq:
      - enable_cloudflare_tunnel
      - true

tunnel_hostname:
  type: string
  title: "Tunnel Hostname"
  description: "Full hostname for KASM access (e.g., kasm.yourdomain.com)"
  required: false
  pattern: "^[a-z0-9-]+\\.[a-z0-9.-]+\\.[a-z]{2,}$"
  visible:
    eq:
      - enable_cloudflare_tunnel
      - true
```

### Phase 5: Update terraform.tfvars.example

**File**: `deploy/kasm/terraform.tfvars.example`

Add Cloudflare section:

```hcl
# =============================================================================
# Cloudflare Tunnel Configuration (Optional)
# =============================================================================

# Enable Cloudflare Tunnel for secure access without opening inbound ports
# enable_cloudflare_tunnel = false

# Cloudflare API Token (requires Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions)
# Get from: https://dash.cloudflare.com/profile/api-tokens
# cloudflare_api_token = "your_api_token_here"

# Cloudflare Account ID (found in dashboard right sidebar)
# cloudflare_account_id = "your_account_id_here"

# Cloudflare Zone ID (found in domain dashboard)
# cloudflare_zone_id = "your_zone_id_here"

# Hostname for KASM access (must be in a domain you manage in Cloudflare)
# tunnel_hostname = "kasm.yourdomain.com"

# KASM web interface port (default: 443)
# kasm_port = 443
```

## Feature Comparison

### Standalone Scripts vs Integrated Approach

| Feature | Standalone Scripts | Integrated (Proposed) |
|---------|-------------------|----------------------|
| **Deployment Method** | Bash scripts + manual steps | Terraform + cloud-init |
| **ORM Compatibility** | ❌ No | ✅ Yes (one-click deploy) |
| **Block Volume Setup** | ✅ Full automation | ⚠️ Needs integration (see block-volume-mount-setup.md) |
| **Tunnel Creation** | ✅ Via API | ✅ Via API (same approach) |
| **DNS Automation** | ✅ CNAME creation | ✅ CNAME creation (same) |
| **Credentials Management** | ✅ JSON file | ✅ JSON file (same) |
| **Systemd Service** | ✅ Auto-start | ✅ Auto-start (same) |
| **Error Handling** | ⚠️ Basic | ✅ Improved with retries |
| **User Experience** | Manual multi-step | One-click deployment |

### Benefits of Integration

1. **ORM Ready**: Works with Resource Manager deploy buttons
2. **Optional Feature**: Disabled by default, enable when needed
3. **Consistent Pattern**: Matches Coolify implementation
4. **Better UX**: No manual script execution required
5. **Validated Inputs**: Terraform variable validation
6. **Status Outputs**: Clear feedback on tunnel status

## Testing Strategy

### Phase 1: Local Testing
1. Update KASM package with Cloudflare variables
2. Test `terraform plan` with tunnel enabled/disabled
3. Validate variable combinations

### Phase 2: Instance Testing
1. Deploy KASM with tunnel disabled (baseline)
2. Deploy KASM with tunnel enabled
3. Verify tunnel creation and DNS setup
4. Test KASM access via tunnel hostname

### Phase 3: Integration Testing
1. Test with different Cloudflare accounts
2. Verify firewall rules (no inbound ports needed)
3. Test tunnel failover and recovery
4. Validate cleanup on `terraform destroy`

## Migration Path

For users of existing standalone scripts:

1. **Continue using scripts**: Still supported, nothing breaks
2. **Migrate to Terraform**: Use new integrated approach
3. **Hybrid approach**: Mix and match as needed

**Recommendation**: New deployments use integrated approach, existing setups can migrate gradually.

## Implementation Priority

### Must-Have (MVP)
1. ✅ Add Terraform variables
2. ✅ Cloud-init tunnel setup script
3. ✅ DNS automation
4. ✅ Systemd service

### Should-Have
1. ⚠️ Schema.yaml updates for ORM UI
2. ⚠️ Output instructions
3. ⚠️ Error handling and retries

### Nice-to-Have
1. 💡 SSH tunnel hostname (like Coolify)
2. 💡 Multiple tunnel support
3. 💡 Tunnel health monitoring

## Security Considerations

1. **API Token**: Stored as sensitive variable, never logged
2. **Credentials File**: Stored with 600 permissions
3. **No Inbound Ports**: Tunnel uses outbound connection only
4. **SSL/TLS**: Handled by Cloudflare, no cert management needed
5. **Firewall**: Can close all inbound ports except SSH (optional)

## Files to Create/Modify

### New Files
- None (all integration in existing files)

### Modified Files
1. `deploy/kasm/variables.tf` - Add Cloudflare variables
2. `deploy/kasm/outputs.tf` - Add tunnel status outputs
3. `deploy/kasm/cloud-init-kasm.yaml` - Add tunnel setup
4. `deploy/kasm/schema.yaml` - Add ORM UI fields
5. `deploy/kasm/terraform.tfvars.example` - Add examples

### Files to Replicate for Full Package
- Same changes to `deploy/full/` (for KASM+Coolify combined)

## Success Criteria

- [ ] Cloudflare variables added to all packages
- [ ] Tunnel setup integrated in cloud-init
- [ ] DNS automation working
- [ ] Systemd service auto-starts
- [ ] ORM UI shows tunnel options
- [ ] Documentation updated
- [ ] Tested with real Cloudflare account
- [ ] Release notes prepared

## Next Steps

1. **Create branch**: `feature/kasm-cloudflare-tunnel`
2. **Implement Phase 1-3**: Core functionality
3. **Test thoroughly**: Multiple deployment scenarios
4. **Update docs**: README and deployment guides
5. **Create PR**: Review and merge
6. **Release**: Include in next version (v1.3.43+)

## References

- Existing Coolify implementation: `deploy/coolify/variables.tf`
- Standalone scripts: `/home/kasm-user/dv/projects/_admin/scripts/oci-kasm-cloudflare/`
- Cloudflare Tunnel API: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- Block volume setup plan: `docs/block-volume-mount-setup.md`
