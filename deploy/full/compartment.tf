resource "oci_identity_compartment" "vibestack" {
  compartment_id = var.parent_compartment_ocid
  description    = "VibeStack compartment - contains KASM and Coolify servers"
  name           = var.compartment_name

  enable_delete = true

  freeform_tags = {
    "Project"     = "VibeStack"
    "Environment" = "Development"
    "CreatedBy"   = "Terraform"
  }
}