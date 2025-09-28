# Random password for Coolify root user
resource "random_password" "coolify_root_password" {
  length  = 24
  special = true
  upper   = true
  lower   = true
  numeric = true
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

  kasm_display_name    = "KASM-server${local.suffix}"
  coolify_display_name = "coolify-server${local.suffix}"

  kasm_hostname    = substr(lower(replace("kasm${local.suffix}", "_", "-")), 0, 63)
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
    var.deploy_kasm ? [for p in var.kasm_custom_tcp_ports : {
      port        = p
      description = "KASM custom port ${p}"
    }] : []
  )

  is_flexible_shape = can(regex("Flex$", var.instance_shape))

  # =============================================================================
  # COOLIFY ROOT USER CONFIGURATION
  # =============================================================================

  # Coolify root user credentials
  coolify_root_username = var.coolify_root_username
  coolify_root_email    = var.coolify_root_user_email
  coolify_root_password = random_password.coolify_root_password.result
}
