resource "oci_core_volume" "kasm_data" {
  count               = var.deploy_kasm ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = "kasm-data${local.suffix}"
  size_in_gbs         = var.kasm_block_volume_size_in_gbs

  # VPUs (Volume Performance Units) - 0 for Always Free tier (Basic performance)
  vpus_per_gb         = "0"
}

resource "oci_core_volume_attachment" "kasm" {
  count           = var.deploy_kasm ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.kasm[0].id
  volume_id       = oci_core_volume.kasm_data[0].id
}

resource "oci_core_volume" "coolify_data" {
  count               = var.deploy_coolify ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = "coolify-data${local.suffix}"
  size_in_gbs         = var.coolify_block_volume_size_in_gbs

  # VPUs (Volume Performance Units) - 0 for Always Free tier (Basic performance)
  vpus_per_gb         = "0"
}

resource "oci_core_volume_attachment" "coolify" {
  count           = var.deploy_coolify ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.coolify[0].id
  volume_id       = oci_core_volume.coolify_data[0].id
}
