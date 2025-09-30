output "compartment" {
  value = {
    name = oci_identity_compartment.vibestack.name
    id   = oci_identity_compartment.vibestack.id
  }
}

output "network" {
  value = {
    vcn_name      = local.vcn_name
    vcn_id        = oci_core_virtual_network.free_tier.id
    subnet_name   = local.subnet_name
    subnet_id     = oci_core_subnet.public.id
    cidr_block    = oci_core_virtual_network.free_tier.cidr_block
    subnet_cidr   = oci_core_subnet.public.cidr_block
    security_list = oci_core_security_list.public.id
  }
}

output "coolify_server" {
  value = var.deploy_coolify ? {
    display_name   = oci_core_instance.coolify[0].display_name
    public_ip      = oci_core_instance.coolify[0].public_ip
    private_ip     = oci_core_instance.coolify[0].private_ip
    block_volume   = oci_core_volume.coolify_data[0].id
    block_size_gb  = var.coolify_block_volume_size_in_gbs
    ocpus          = var.coolify_ocpus
    memory_in_gbs  = var.coolify_memory_in_gbs
  } : null
}

output "security_list_ingress_ports" {
  value = [for rule in local.ingress_tcp_ports : rule.port]
}

output "ansible_setup_status" {
  description = "Status of Ansible setup completion"
  value = var.deploy_coolify ? "Terraform has waited for Ansible setup to complete. Check /opt/vibestack-ansible/setup-complete on the instance for details." : null
}

# =============================================================================
# CLOUDFLARE TUNNEL OUTPUTS
# =============================================================================

output "cloudflare_tunnel_enabled" {
  description = "Whether Cloudflare tunnel was configured"
  value       = local.setup_cloudflare_tunnel
  sensitive   = true
}

output "coolify_url" {
  description = "URL to access Coolify"
  value = var.deploy_coolify ? (
    local.setup_cloudflare_tunnel ? "https://${var.tunnel_hostname}" : "http://${oci_core_instance.coolify[0].public_ip}:8000"
  ) : null
}

output "coolify_credentials" {
  description = "Coolify login information"
  value = var.deploy_coolify ? {
    email    = local.coolify_root_email
    password = local.coolify_root_password
    note     = "Save these credentials securely - they won't be shown again"
  } : null
  sensitive = true
}

output "ssh_access" {
  description = "SSH access information"
  value = var.deploy_coolify ? (
    local.setup_cloudflare_tunnel ?
      "SSH access via tunnel: ${local.final_ssh_hostname}" :
      "SSH access: ubuntu@${oci_core_instance.coolify[0].public_ip}"
  ) : null
}

output "tunnel_name" {
  description = "Cloudflare tunnel name (if configured)"
  value       = local.setup_cloudflare_tunnel ? local.tunnel_name : null
  sensitive   = false
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value = var.deploy_coolify ? (
    local.setup_cloudflare_tunnel ? [
      "═══════════════════════════════════════════════════════════════════",
      "✅ COOLIFY DEPLOYED - FULLY AUTOMATED SETUP",
      "═══════════════════════════════════════════════════════════════════",
      "",
      "⏱️  Please wait 5-7 minutes for automated setup to complete",
      "",
      "🌐 Access Coolify: https://${var.tunnel_hostname}",
      "📧 Login Email: ${local.coolify_root_email}",
      "🔑 Password: ${local.coolify_root_password}",
      "",
      "✨ Everything is configured automatically:",
      "   • Cloudflare tunnel ✓",
      "   • SSL certificates ✓",
      "   • Wildcard domains ✓",
      "   • Root user account ✓",
      "",
      "No SSH or manual configuration needed!",
      "═══════════════════════════════════════════════════════════════════"
    ] : [
      "═══════════════════════════════════════════════════════════════════",
      "✅ COOLIFY DEPLOYED - MANUAL TUNNEL SETUP REQUIRED",
      "═══════════════════════════════════════════════════════════════════",
      "",
      "⏱️  Please wait 3-5 minutes for initial setup",
      "",
      "🌐 Access Coolify: http://${oci_core_instance.coolify[0].public_ip}:8000",
      "📧 Login Email: ${local.coolify_root_email}",
      "🔑 Password: ${local.coolify_root_password}",
      "",
      "📌 To enable HTTPS access via Cloudflare:",
      "   1️⃣  Login to Coolify",
      "   ☁️  Create new 'cloudflared' service",
      "   🔐  Enter your Cloudflare tunnel token",
      "   🚀  Deploy the service",
      "",
      "🌐 Then access at: https://your-domain.com",
      "═══════════════════════════════════════════════════════════════════"
    ]
  ) : null
  sensitive = true
}
