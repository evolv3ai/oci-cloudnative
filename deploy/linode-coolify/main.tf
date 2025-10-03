# =============================================================================
# LINODE COOLIFY DEPLOYMENT
# =============================================================================

locals {
  # Process cloud-init template
  cloud_init_content = templatefile("${path.module}/cloud-init-coolify.yaml", {
    instance_label              = var.instance_label
    enable_cloudflare_tunnel    = var.enable_cloudflare_tunnel
    cloudflare_api_token        = var.cloudflare_api_token
    cloudflare_account_id       = var.cloudflare_account_id
    cloudflare_zone_id          = var.cloudflare_zone_id
    tunnel_hostname             = var.tunnel_hostname
    coolify_root_username       = var.coolify_root_username
    coolify_root_email          = var.coolify_root_email
    coolify_root_password       = var.coolify_root_password
    ssh_authorized_keys         = var.ssh_authorized_keys
    skip_ansible_execution      = var.skip_ansible_execution
  })
}

# =============================================================================
# LINODE INSTANCE
# =============================================================================

resource "linode_instance" "coolify" {
  label           = var.instance_label
  region          = var.region
  type            = var.instance_type
  image           = var.image
  root_pass       = var.root_pass
  authorized_keys = [for key in split("\n", var.ssh_authorized_keys) : trimspace(key) if trimspace(key) != ""]
  tags            = var.tags

  # Cloud-init configuration
  metadata {
    user_data = base64encode(local.cloud_init_content)
  }

  lifecycle {
    ignore_changes = [
      metadata
    ]
  }
}

# =============================================================================
# BLOCK STORAGE VOLUME
# =============================================================================

resource "linode_volume" "coolify_data" {
  label     = "${var.instance_label}-data"
  region    = var.region
  size      = var.block_storage_size
  linode_id = linode_instance.coolify.id
  tags      = concat(var.tags, ["storage"])

  lifecycle {
    prevent_destroy = false
  }
}

# =============================================================================
# FIREWALL RULES
# =============================================================================

resource "linode_firewall" "coolify" {
  label           = "${var.instance_label}-firewall"
  tags            = var.tags
  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  # SSH access (always enabled)
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # Only open HTTP/HTTPS if Cloudflare tunnel is NOT enabled
  dynamic "inbound" {
    for_each = var.enable_cloudflare_tunnel ? [] : [1]

    content {
      label    = "allow-http"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "80"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  }

  dynamic "inbound" {
    for_each = var.enable_cloudflare_tunnel ? [] : [1]

    content {
      label    = "allow-https"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "443"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  }

  dynamic "inbound" {
    for_each = var.enable_cloudflare_tunnel ? [] : [1]

    content {
      label    = "allow-coolify-web"
      action   = "ACCEPT"
      protocol = "TCP"
      ports    = "8000"
      ipv4     = ["0.0.0.0/0"]
      ipv6     = ["::/0"]
    }
  }

  # Attach to instance
  linodes = [linode_instance.coolify.id]
}
