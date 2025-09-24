data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

locals {
  selected_ad      = trimspace(var.availability_domain != "" ? var.availability_domain : try(data.oci_identity_availability_domains.ads.availability_domains[0].name, ""))
  use_image_lookup = var.custom_image_ocid == ""
}

data "oci_core_images" "default" {
  count                    = local.use_image_lookup ? 1 : 0
  compartment_id           = oci_identity_compartment.vibestack.id
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  resolved_image_id = local.use_image_lookup ? try(data.oci_core_images.default[0].images[0].id, "") : var.custom_image_ocid
}
