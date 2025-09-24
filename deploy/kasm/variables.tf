variable "tenancy_ocid" {
  description = "OCID of the tenancy where resources will be created."
  type        = string
}

variable "region" {
  description = "OCI region identifier (for example, us-phoenix-1)."
  type        = string
}

variable "parent_compartment_ocid" {
  description = "OCID of the parent compartment where the new compartment will be created. Use tenancy OCID for root compartment."
  type        = string
}

variable "compartment_name" {
  description = "Name for the new compartment that will contain all VibeStack resources."
  type        = string
  default     = "vibestack"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,99}$", var.compartment_name))
    error_message = "Compartment name must start with a letter and can only contain letters, numbers, hyphens, and underscores. Maximum 100 characters."
  }
}

variable "user_ocid" {
  description = "OCID of the user that Terraform should authenticate as. Leave blank when using the OCI Cloud Shell or Resource Manager."
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "API signing key fingerprint. Leave blank when using the OCI Cloud Shell or Resource Manager."
  type        = string
  default     = ""
}

variable "private_key_path" {
  description = "Path to the API signing private key. Leave blank when using the OCI Cloud Shell or Resource Manager."
  type        = string
  default     = ""
}


variable "ssh_authorized_keys" {
  description = "One or more SSH public keys that should be added to the compute instances."
  type        = string
}

variable "instance_shape" {
  description = "Compute shape for both servers. Must remain within the Always Free eligible shapes."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "availability_domain" {
  description = "Optional availability domain name. When omitted the first available AD in the tenancy is used."
  type        = string
  default     = ""
}

variable "deployment_label" {
  description = "Optional suffix appended to resource names to keep them unique."
  type        = string
  default     = ""
}

variable "image_operating_system" {
  description = "Operating system to use when looking up the base image."
  type        = string
  default     = "Canonical Ubuntu"
}

variable "image_operating_system_version" {
  description = "Operating system version to use when looking up the base image."
  type        = string
  default     = "22.04"
}

variable "custom_image_ocid" {
  description = "Optional custom image OCID to override the automatic image lookup."
  type        = string
  default     = ""
}

variable "kasm_ocpus" {
  description = "Number of OCPUs allocated to the KASM server."
  type        = number
  default     = 2
}

variable "kasm_memory_in_gbs" {
  description = "Memory (in GB) allocated to the KASM server."
  type        = number
  default     = 12
}

variable "kasm_block_volume_size_in_gbs" {
  description = "Size of the additional block volume attached to the KASM server."
  type        = number
  default     = 60
}

variable "kasm_custom_tcp_ports" {
  description = "Additional TCP ports that should be opened to the KASM server."
  type        = list(number)
  default     = []
}

variable "assign_public_ip" {
  description = "Assign public IPv4 addresses to the compute instances."
  type        = bool
  default     = true
}

variable "deploy_kasm" {
  description = "Deploy KASM Workspaces server."
  type        = bool
  default     = true
}

variable "deploy_coolify" {
  description = "Deploy Coolify server."
  type        = bool
  default     = true
}
