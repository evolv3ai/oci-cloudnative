
resource "oci_core_instance" "coolify" {
  count               = var.deploy_coolify ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = local.coolify_display_name
  shape               = var.instance_shape

  dynamic "shape_config" {
    for_each = local.is_flexible_shape ? [1] : []
    content {
      ocpus         = var.coolify_ocpus
      memory_in_gbs = var.coolify_memory_in_gbs
    }
  }

  create_vnic_details {
    assign_public_ip = var.assign_public_ip
    hostname_label   = local.coolify_hostname
    subnet_id        = oci_core_subnet.public.id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data = base64encode(templatefile("${path.module}/cloud-init-coolify.yaml", {
      ssh_authorized_keys    = var.ssh_authorized_keys
      cloudflare_env_vars    = local.cloudflare_env_vars
      setup_custom_ssl       = local.setup_custom_ssl
      ssl_cert_b64           = local.ssl_cert_b64
      ssl_key_b64            = local.ssl_key_b64
      ssl_chain_b64          = local.ssl_chain_b64
      skip_ansible_execution = var.skip_ansible_execution
      coolify_root_username  = local.coolify_root_username
      coolify_root_email     = local.coolify_root_email
      coolify_root_password  = local.coolify_root_password
    }))
  }

  source_details {
    source_type = "image"
    source_id   = local.resolved_image_id
  }

  lifecycle {
    precondition {
      condition     = local.selected_ad != ""
      error_message = "Unable to determine an availability domain. Provide availability_domain explicitly."
    }

    precondition {
      condition     = local.resolved_image_id != ""
      error_message = "Unable to resolve a compute image. Specify custom_image_ocid to proceed."
    }
  }
}
