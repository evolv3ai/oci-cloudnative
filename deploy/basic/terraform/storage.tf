resource "oci_core_volume" "kasm_data" {
  availability_domain = local.selected_ad
  compartment_id      = var.compartment_ocid
  display_name        = "kasm-data${local.suffix}"
  size_in_gbs         = var.kasm_block_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "kasm" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.kasm.id
  volume_id       = oci_core_volume.kasm_data.id
}

resource "oci_core_volume" "coolify_data" {
  availability_domain = local.selected_ad
  compartment_id      = var.compartment_ocid
  display_name        = "coolify-data${local.suffix}"
  size_in_gbs         = var.coolify_block_volume_size_in_gbs
}

resource "oci_core_volume_attachment" "coolify" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.coolify.id
  volume_id       = oci_core_volume.coolify_data.id
}
