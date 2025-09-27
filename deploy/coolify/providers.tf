terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">= 5.10.0, < 7.20.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  region           = var.region
  user_ocid        = var.user_ocid != "" ? var.user_ocid : null
  fingerprint      = var.fingerprint != "" ? var.fingerprint : null
  private_key_path = var.private_key_path != "" ? var.private_key_path : null
}
