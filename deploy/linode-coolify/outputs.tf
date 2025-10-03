# =============================================================================
# LOCAL HELPERS
# =============================================================================

locals {
  instance_ip = tolist(linode_instance.coolify.ipv4)[0]
}

# =============================================================================
# INSTANCE INFORMATION
# =============================================================================

output "instance_id" {
  description = "Linode instance ID"
  value       = linode_instance.coolify.id
}

output "instance_label" {
  description = "Linode instance label"
  value       = linode_instance.coolify.label
}

output "instance_ip" {
  description = "Public IP address of the Coolify server"
  value       = local.instance_ip
}

output "instance_ipv6" {
  description = "IPv6 address of the Coolify server"
  value       = linode_instance.coolify.ipv6
}

output "region" {
  description = "Deployment region"
  value       = linode_instance.coolify.region
}

# =============================================================================
# STORAGE INFORMATION
# =============================================================================

output "volume_id" {
  description = "Block storage volume ID"
  value       = linode_volume.coolify_data.id
}

output "volume_size" {
  description = "Block storage volume size (GB)"
  value       = linode_volume.coolify_data.size
}

# =============================================================================
# ACCESS INFORMATION
# =============================================================================

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${local.instance_ip}"
}

output "coolify_url_http" {
  description = "Coolify web interface URL (HTTP)"
  value       = var.enable_cloudflare_tunnel ? "Accessible via Cloudflare tunnel only" : "http://${local.instance_ip}:8000"
}

output "coolify_url_tunnel" {
  description = "Coolify URL via Cloudflare tunnel"
  value       = var.enable_cloudflare_tunnel && var.tunnel_hostname != "" ? "https://${var.tunnel_hostname}" : "Cloudflare tunnel not configured"
}

# =============================================================================
# CLOUDFLARE TUNNEL INFORMATION
# =============================================================================

output "cloudflare_tunnel_status" {
  description = "Cloudflare Tunnel configuration status"
  value = var.enable_cloudflare_tunnel ? {
    enabled        = true
    hostname       = var.tunnel_hostname
    access_url     = "https://${var.tunnel_hostname}"
    setup_complete = "Tunnel configured during cloud-init"
  } : {
    enabled = false
    message = "Cloudflare Tunnel is disabled. Access Coolify via public IP."
  }
}

# =============================================================================
# DEPLOYMENT INSTRUCTIONS
# =============================================================================

output "deployment_instructions" {
  description = "Post-deployment instructions"
  value       = <<-EOT

    ╔════════════════════════════════════════════════════════════════════════╗
    ║                 COOLIFY DEPLOYMENT SUCCESSFUL (LINODE)                 ║
    ╚════════════════════════════════════════════════════════════════════════╝

    📊 Instance Information:
    ├─ Instance ID:    ${linode_instance.coolify.id}
    ├─ Label:          ${linode_instance.coolify.label}
    ├─ Region:         ${linode_instance.coolify.region}
    ├─ Public IP:      ${local.instance_ip}
    └─ IPv6:           ${linode_instance.coolify.ipv6}

    💾 Storage:
    ├─ Volume ID:      ${linode_volume.coolify_data.id}
    ├─ Volume Size:    ${linode_volume.coolify_data.size} GB
    └─ Mount Point:    /mnt/coolify-data

    🔐 SSH Access:
    └─ ssh ubuntu@${local.instance_ip}

    🌐 Access:
    ├─ Tunnel:         ${var.enable_cloudflare_tunnel ? "https://${var.tunnel_hostname}" : "Not enabled"}
    └─ Direct:         ${var.enable_cloudflare_tunnel ? "Via tunnel only" : "http://${local.instance_ip}:8000"}

    📝 Monitor Setup Progress:
    ├─ Main setup:     ssh ubuntu@${local.instance_ip} 'tail -f /var/log/vibestack-setup.log'
    ├─ Coolify:        ssh ubuntu@${local.instance_ip} 'tail -f /var/log/coolify-install.log'
    ${var.enable_cloudflare_tunnel ? "└─ Tunnel:         ssh ubuntu@${local.instance_ip} 'tail -f /var/log/cloudflare-tunnel.log'" : ""}

    ${var.enable_cloudflare_tunnel ? "🔍 Check Tunnel Status:\n    └─ ssh ubuntu@${local.instance_ip} 'sudo systemctl status cloudflared-coolify-tunnel'" : ""}

    ⚠️  IMPORTANT:
    - Setup is running in the background via cloud-init
    - Allow 5-10 minutes for complete installation
    - Access Coolify at: ${var.enable_cloudflare_tunnel ? "https://${var.tunnel_hostname}" : "http://${local.instance_ip}:8000"}

    📚 Next Steps:
    1. Wait for setup to complete (monitor logs above)
    2. Access Coolify at ${var.enable_cloudflare_tunnel ? "https://${var.tunnel_hostname}" : "http://${local.instance_ip}:8000"}
    3. Login with credentials from terraform.tfvars
    4. Configure your first application

  EOT
}
