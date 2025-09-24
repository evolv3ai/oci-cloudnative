resource "oci_core_volume" "kasm_data" {
  count               = var.deploy_kasm ? 1 : 0
  availability_domain = local.selected_ad
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = "kasm-data${local.suffix}"
  size_in_gbs         = var.kasm_block_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "kasm" {
  count           = var.deploy_kasm ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.kasm[0].id
  volume_id       = oci_core_volume.kasm_data[0].id
}

