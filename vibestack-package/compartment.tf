resource "oci_identity_compartment" "devlab" {
  compartment_id = var.parent_compartment_ocid
  description    = "VibeStack development laboratory - contains KASM and Coolify servers"
  name           = "devlab"

  enable_delete = true

  freeform_tags = {
    "Project"     = "VibeStack"
    "Environment" = "Development"
    "CreatedBy"   = "Terraform"
  }
}