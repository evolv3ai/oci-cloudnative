
resource "oci_core_volume" "coolify_data" {
  count               = var.deploy_coolify ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = "coolify-data${local.suffix}"
  size_in_gbs         = var.coolify_block_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "coolify" {
  count           = var.deploy_coolify ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.coolify[0].id
  volume_id       = oci_core_volume.coolify_data[0].id
}
