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

# =============================================================================
# CLOUDFLARE TUNNEL OUTPUTS
# =============================================================================

output "cloudflare_tunnel_enabled" {
  description = "Whether Cloudflare tunnel was configured"
  value       = local.setup_cloudflare_tunnel
}

output "coolify_url" {
  description = "URL to access Coolify"
  value = var.deploy_coolify ? (
    local.setup_cloudflare_tunnel ? "https://${var.tunnel_hostname}" : "http://${oci_core_instance.coolify[0].public_ip}:8000"
  ) : null
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
      "✅ Coolify deployed with Cloudflare tunnel",
      "🌐 Access Coolify at: https://${var.tunnel_hostname}",
      "🔐 SSH access at: ${local.final_ssh_hostname}",
      "⏱️ Allow 5-7 minutes for tunnel setup to complete",
      "📋 Check deployment status: ssh ubuntu@${oci_core_instance.coolify[0].public_ip} 'cat /opt/vibestack-ansible/deployment-success.txt'"
    ] : [
      "✅ Coolify deployed successfully",
      "🌐 Access Coolify at: http://${oci_core_instance.coolify[0].public_ip}:8000",
      "🔐 SSH access: ubuntu@${oci_core_instance.coolify[0].public_ip}",
      "⏱️ Allow 3-5 minutes for setup to complete",
      "💡 To add Cloudflare tunnel later, check: /opt/vibestack-ansible/README.md"
    ]
  ) : null
}
