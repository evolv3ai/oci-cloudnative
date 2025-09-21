terraform {
  required_version = ">= 1.3.0"

  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">= 5.10.0"
    }
  }
}

provider "oci" {
  tenancy_ocid         = var.tenancy_ocid
  region               = var.region
  user_ocid            = var.user_ocid
  fingerprint          = var.fingerprint
  private_key_path     = var.private_key_path
  config_file_profile  = var.config_file_profile
}
