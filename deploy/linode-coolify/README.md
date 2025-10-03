# Coolify Deployment for Linode

Deploy a complete Coolify server on Linode with optional Cloudflare Tunnel support.

## Overview

This Terraform configuration deploys:
- **Linode Instance**: Ubuntu 22.04 server with Coolify pre-installed
- **Block Storage**: Persistent storage for Docker volumes and application data
- **Cloudflare Tunnel** (optional): Secure access without opening public ports
- **Firewall**: Configured security rules

## Prerequisites

1. **Linode Account**
   - Active Linode account
   - API token with read/write permissions
   - Get from: https://cloud.linode.com/profile/tokens

2. **Cloudflare Account** (if using tunnels)
   - Domain managed by Cloudflare
   - API token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions
   - Get from: https://dash.cloudflare.com/profile/api-tokens

3. **Local Requirements**
   - Terraform >= 1.0
   - SSH key pair

## Quick Start

### 1. Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Required variables:**
- `linode_token` - Your Linode API token
- `root_pass` - Root password for the instance (min 11 chars)
- `ssh_authorized_keys` - Your SSH public key(s)
- `coolify_root_email` - Email for Coolify admin account
- `coolify_root_password` - Password for Coolify admin account

**Cloudflare Tunnel variables** (if `enable_cloudflare_tunnel = true`):
- `cloudflare_api_token`
- `cloudflare_account_id`
- `cloudflare_zone_id`
- `tunnel_hostname`

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

### 3. Access Coolify

**With Cloudflare Tunnel (enabled by default):**
```
https://coolify.yourdomain.com
```

**Without Cloudflare Tunnel:**
```
http://<instance-ip>:8000
```

Login with credentials from `terraform.tfvars`.

## Configuration Options

### Instance Types

| Type | RAM | CPU | Monthly Cost | Use Case |
|------|-----|-----|--------------|----------|
| g6-nanode-1 | 1GB | 1 | $5 | Minimal/Testing |
| g6-standard-1 | 2GB | 1 | $10 | Light usage |
| **g6-standard-2** | 4GB | 2 | $20 | **Recommended** |
| g6-standard-4 | 8GB | 2 | $40 | Heavy usage |

### Regions

Available Linode regions:
- `us-east` - Newark, NJ
- `us-central` - Dallas, TX
- `us-west` - Fremont, CA
- `eu-west` - London, UK
- `ap-south` - Singapore
- And more: https://www.linode.com/docs/products/platform/get-started/guides/choose-a-data-center/

### Storage

Block storage pricing: $0.10/GB per month

Recommended sizes:
- **100GB** - Standard deployment (default)
- 200GB - Heavy application usage
- 500GB+ - Large-scale deployments

## Cloudflare Tunnel Setup

### Why Use Cloudflare Tunnel?

✅ **Security**: No open HTTP/HTTPS ports
✅ **DDoS Protection**: Cloudflare's built-in protection
✅ **SSL/TLS**: Automatic HTTPS with Cloudflare certificates
✅ **Access Control**: Integrate with Cloudflare Access
✅ **No Port Forwarding**: Works behind any firewall

### Setup Steps

1. **Enable in terraform.tfvars:**
   ```hcl
   enable_cloudflare_tunnel = true
   ```

2. **Configure Cloudflare credentials:**
   - Get API token: https://dash.cloudflare.com/profile/api-tokens
   - Find Account ID: Dashboard → Right sidebar
   - Find Zone ID: Domain dashboard → Overview → Right sidebar

3. **Set tunnel hostname:**
   ```hcl
   tunnel_hostname = "coolify.yourdomain.com"
   ```

4. **Deploy and wait:**
   - Tunnel auto-configures during cloud-init
   - DNS CNAME record created automatically
   - Access via HTTPS within 5-10 minutes

### Verify Tunnel Status

```bash
# SSH into instance
ssh ubuntu@<instance-ip>

# Check tunnel service
sudo systemctl status cloudflared-coolify-tunnel

# View tunnel logs
sudo journalctl -u cloudflared-coolify-tunnel -f

# View tunnel info
cat /opt/vibestack/cloudflare-tunnel-info.txt
```

## Monitoring Setup Progress

All setup happens automatically via cloud-init. Monitor progress:

```bash
# SSH into instance
ssh ubuntu@<instance-ip>

# Main setup log
tail -f /var/log/vibestack-setup.log

# Coolify installation log
tail -f /var/log/coolify-install.log

# Cloudflare tunnel log (if enabled)
tail -f /var/log/cloudflare-tunnel.log
```

Setup typically takes 5-10 minutes.

## Post-Deployment

### Verify Coolify Installation

```bash
# Check Coolify service
ssh ubuntu@<instance-ip> 'docker ps'

# Should show Coolify containers running
```

### Check Block Storage

```bash
# Verify volume is mounted
ssh ubuntu@<instance-ip> 'df -h | grep coolify'

# Should show /mnt/coolify-data mounted
```

### Configure Coolify

1. Access Coolify web interface
2. Login with admin credentials
3. Go through initial setup wizard
4. Add your first application

## Troubleshooting

### Coolify Not Accessible

**With Cloudflare Tunnel:**
```bash
# Check tunnel status
ssh ubuntu@<instance-ip> 'sudo systemctl status cloudflared-coolify-tunnel'

# Check DNS propagation
dig coolify.yourdomain.com

# View tunnel logs
ssh ubuntu@<instance-ip> 'sudo journalctl -u cloudflared-coolify-tunnel -n 100'
```

**Without Cloudflare Tunnel:**
```bash
# Check if Coolify is running
ssh ubuntu@<instance-ip> 'curl http://localhost:8000'

# Check firewall
ssh ubuntu@<instance-ip> 'sudo iptables -L -n | grep 8000'
```

### Volume Not Mounted

```bash
# Check volume attachment
ssh ubuntu@<instance-ip> 'lsblk'

# Manually mount if needed
ssh ubuntu@<instance-ip> 'sudo mount /dev/sdc /mnt/coolify-data'
```

### Cloud-Init Failed

```bash
# View cloud-init logs
ssh ubuntu@<instance-ip> 'sudo cat /var/log/cloud-init-output.log'

# Check for errors
ssh ubuntu@<instance-ip> 'sudo cloud-init status'
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning:** This will:
- Delete the Linode instance
- Delete the block storage volume (and all data)
- Remove firewall rules
- NOT delete Cloudflare tunnel (manual cleanup required)

### Manual Cloudflare Cleanup

If you enabled Cloudflare tunnel:

1. Go to: https://dash.cloudflare.com
2. Navigate to: Zero Trust → Networks → Tunnels
3. Find tunnel: `coolify-tunnel-<instance-label>`
4. Delete the tunnel
5. Remove DNS CNAME record from your domain

## Cost Estimate

**Minimal Setup** (g6-standard-2 + 100GB storage):
- Instance: $20/month
- Storage: $10/month
- **Total: ~$30/month**

**Production Setup** (g6-standard-4 + 200GB storage):
- Instance: $40/month
- Storage: $20/month
- **Total: ~$60/month**

Cloudflare Tunnel: Free (included in free tier)

## Security Best Practices

1. **Use Cloudflare Tunnel** - Eliminates exposed ports
2. **Strong Passwords** - Use complex passwords for root and Coolify
3. **SSH Keys Only** - Password auth is disabled by default
4. **Regular Updates** - Keep system and Coolify updated
5. **Firewall Rules** - Only open required ports
6. **Backup Strategy** - Regular backups of `/mnt/coolify-data`

## Advanced Configuration

### Custom SSH Key Path

Update [main.tf:78](main.tf#L78) with your SSH key location:

```terraform
private_key = file("~/.ssh/your_custom_key")
```

### Additional Firewall Rules

Edit [main.tf:103](main.tf#L103) to add custom rules:

```terraform
inbound {
  label    = "custom-port"
  action   = "ACCEPT"
  protocol = "TCP"
  ports    = "3000"
  ipv4     = ["0.0.0.0/0"]
}
```

### Testing Mode

To deploy without automatic setup (for testing):

```hcl
skip_ansible_execution = true
```

Then manually run scripts:
```bash
ssh ubuntu@<instance-ip> '/opt/vibestack/install-coolify.sh'
ssh ubuntu@<instance-ip> '/opt/vibestack/setup-cloudflare-tunnel.sh'
```

## Support

- **Linode Docs**: https://www.linode.com/docs/
- **Coolify Docs**: https://coolify.io/docs
- **Cloudflare Tunnel**: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- **Terraform Linode Provider**: https://registry.terraform.io/providers/linode/linode/latest/docs

## Architecture

```
┌─────────────────────────────────────────────────┐
│             Cloudflare Network                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Cloudflare Tunnel (Optional)            │   │
│  │  - SSL/TLS termination                   │   │
│  │  - DDoS protection                       │   │
│  │  - Access control                        │   │
│  └──────────────────────────────────────────┘   │
└─────────────────┬───────────────────────────────┘
                  │
                  │ Outbound connection only
                  │
┌─────────────────▼───────────────────────────────┐
│           Linode Instance                       │
│  ┌──────────────────────────────────────────┐   │
│  │  Ubuntu 22.04                            │   │
│  │  - Docker + Docker Compose               │   │
│  │  - Coolify (localhost:8000)              │   │
│  │  - Cloudflared (tunnel agent)            │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Block Storage Volume                    │   │
│  │  - /mnt/coolify-data                     │   │
│  │  - Docker volumes                        │   │
│  │  - Application data                      │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

## License

This configuration is part of the VibeStack project and follows the same license as the parent repository.
