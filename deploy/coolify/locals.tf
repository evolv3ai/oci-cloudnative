# Random suffix for unique tunnel naming
resource "random_string" "tunnel_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Random password for Coolify root user
resource "random_password" "coolify_root_password" {
  length           = 24
  special          = true
  override_special = "!^*"
  min_special      = 1
  upper            = true
  lower            = true
  numeric          = true
}

locals {
  trimmed_label = trimspace(var.deployment_label)
  suffix        = local.trimmed_label == "" ? "" : "-${local.trimmed_label}"

  vcn_name           = "free-tier-vcn${local.suffix}"
  subnet_name        = "public-subnet-1${local.suffix}"
  route_table_name   = "free-tier-rt${local.suffix}"
  igw_name           = "free-tier-igw${local.suffix}"
  security_list_name = "free-tier-sl${local.suffix}"

  vcn_dns_label    = substr(replace("freetiervcn${replace(local.suffix, "-", "")}", "_", ""), 0, 15)
  subnet_dns_label = substr(replace("publicsubnet${replace(local.suffix, "-", "")}", "_", ""), 0, 15)

  coolify_display_name = "coolify-server${local.suffix}"

  coolify_hostname = substr(lower(replace("coolify${local.suffix}", "_", "-")), 0, 63)

  ingress_tcp_ports = concat(
    [
      {
        port        = 22
        description = "SSH"
      },
      {
        port        = 80
        description = "HTTP"
      },
      {
        port        = 443
        description = "HTTPS"
      }
    ],
    var.deploy_coolify ? [
      {
        port        = 8000
        description = "Coolify Web Interface"
      },
      {
        port        = 6001
        description = "Coolify Real-time Communications"
      },
      {
        port        = 6002
        description = "Coolify Terminal Access"
      }
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

  # Determine if Cloudflare tunnel should be configured
  setup_cloudflare_tunnel = var.enable_cloudflare_tunnel && var.cloudflare_api_token != "" && var.tunnel_hostname != ""

  # Auto-generate SSH hostname if not provided
  final_ssh_hostname = var.ssh_hostname != "" ? var.ssh_hostname : (
    var.tunnel_hostname != "" ? "ssh.${join(".", slice(split(".", var.tunnel_hostname), 1, length(split(".", var.tunnel_hostname))))}" : ""
  )

  # Auto-generate tunnel name
  tunnel_name = "vibestack-coolify${local.suffix}-${random_string.tunnel_suffix.result}"

  # Cloudflare environment variables for cloud-init
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
  # SSL CERTIFICATE CONFIGURATION
  # =============================================================================

  # Determine if custom SSL should be configured
  setup_custom_ssl = var.enable_custom_ssl && var.origin_certificate != "" && var.private_key != ""

  # SSL certificate content (base64 encoded for safe transmission)
  ssl_cert_b64 = local.setup_custom_ssl ? base64encode(var.origin_certificate) : ""
  ssl_key_b64 = local.setup_custom_ssl ? base64encode(var.private_key) : ""
  ssl_chain_b64 = ""

  # =============================================================================
  # COOLIFY ROOT USER CONFIGURATION
  # =============================================================================

  # Coolify root user credentials
  coolify_root_username = var.coolify_root_username
  coolify_root_email    = var.coolify_root_user_email
  coolify_root_password = random_password.coolify_root_password.result
}
