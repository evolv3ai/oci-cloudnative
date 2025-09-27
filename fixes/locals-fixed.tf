# locals.tf - FIXED SSL handling

# Random suffix for unique tunnel naming
resource "random_string" "tunnel_suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  trimmed_label = trimspace(var.deployment_label)
  suffix        = local.trimmed_label == "" ? "" : "-${local.trimmed_label}"

  # Network naming
  vcn_name           = "free-tier-vcn${local.suffix}"
  subnet_name        = "public-subnet-1${local.suffix}"
  route_table_name   = "free-tier-rt${local.suffix}"
  igw_name           = "free-tier-igw${local.suffix}"
  security_list_name = "free-tier-sl${local.suffix}"

  vcn_dns_label    = substr(replace("freetiervcn${replace(local.suffix, "-", "")}", "_", ""), 0, 15)
  subnet_dns_label = substr(replace("publicsubnet${replace(local.suffix, "-", "")}", "_", ""), 0, 15)

  # Coolify naming
  coolify_display_name = "coolify-server${local.suffix}"
  coolify_hostname = substr(lower(replace("coolify${local.suffix}", "_", "-")), 0, 63)

  # Security group ingress ports
  ingress_tcp_ports = concat(
    [
      { port = 22, description = "SSH" },
      { port = 80, description = "HTTP" },
      { port = 443, description = "HTTPS" }
    ],
    var.deploy_coolify ? [
      { port = 8000, description = "Coolify Web Interface" },
      { port = 6001, description = "Coolify Real-time Communications" },
      { port = 6002, description = "Coolify Terminal Access" }
    ] : [],
    var.deploy_coolify ? [for p in var.coolify_custom_tcp_ports : {
      port        = p
      description = "Coolify custom port ${p}"
    }] : []
  )

  is_flexible_shape = can(regex("Flex$", var.instance_shape))

  # =============================================================================
  # CLOUDFLARE TUNNEL CONFIGURATION
  # =============================================================================

  setup_cloudflare_tunnel = var.enable_cloudflare_tunnel && var.cloudflare_api_token != "" && var.tunnel_hostname != ""
  
  final_ssh_hostname = var.ssh_hostname != "" ? var.ssh_hostname : (
    var.tunnel_hostname != "" ? "ssh.${join(".", slice(split(".", var.tunnel_hostname), 1, length(split(".", var.tunnel_hostname))))}" : ""
  )
  
  tunnel_name = "vibestack-coolify${local.suffix}-${random_string.tunnel_suffix.result}"

  cloudflare_env_vars = local.setup_cloudflare_tunnel ? [
    "ENABLE_CLOUDFLARE_TUNNEL=true",
    "CLOUDFLARE_API_TOKEN=${var.cloudflare_api_token}",
    "CLOUDFLARE_ACCOUNT_ID=${var.cloudflare_account_id}",
    "CLOUDFLARE_ZONE_ID=${var.cloudflare_zone_id}",
    "TUNNEL_HOSTNAME=${var.tunnel_hostname}",
    "SSH_HOSTNAME=${local.final_ssh_hostname}",
    "TUNNEL_NAME=${local.tunnel_name}"
  ] : [
    "ENABLE_CLOUDFLARE_TUNNEL=false"
  ]

  # =============================================================================
  # SSL CERTIFICATE CONFIGURATION - FIXED
  # =============================================================================

  setup_custom_ssl = var.enable_custom_ssl && var.origin_certificate != "" && var.private_key != ""

  # Function to clean PEM content - remove extra whitespace but preserve format
  clean_pem = {
    cert = local.setup_custom_ssl ? trimspace(var.origin_certificate) : ""
    key  = local.setup_custom_ssl ? trimspace(var.private_key) : ""
  }

  # Base64 encode the already-PEM-formatted certificates
  # This preserves the exact format including line breaks
  ssl_cert_b64  = local.setup_custom_ssl ? base64encode(local.clean_pem.cert) : ""
  ssl_key_b64   = local.setup_custom_ssl ? base64encode(local.clean_pem.key) : ""
  ssl_chain_b64 = ""  # Chain certificate support if needed later

  # AD and image resolution
  selected_ad = var.availability_domain != "" ? var.availability_domain : (
    length(data.oci_identity_availability_domains.ads.availability_domains) > 0
    ? data.oci_identity_availability_domains.ads.availability_domains[0].name
    : ""
  )

  resolved_image_id = var.custom_image_ocid != "" ? var.custom_image_ocid : (
    length(data.oci_core_images.compute_images.images) > 0
    ? data.oci_core_images.compute_images.images[0].id
    : ""
  )
}
