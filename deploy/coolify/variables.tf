variable "tenancy_ocid" {
  description = "OCID of the tenancy where resources will be created."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.oc1\\..+[a-z0-9]{60}$", var.tenancy_ocid))
    error_message = "The tenancy_ocid must be a valid Oracle Cloud Tenancy OCID value (e.g. ocid1.tenancy.oc1..aaaaaaaaba3pv6wkcr4jqae5f44n2b2m2yt2j6rx32uzr4h25vqstifsfdsq)."
  }
}

variable "region" {
  description = "OCI region identifier (for example, us-phoenix-1)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]{5,}-[0-9]{1}$", var.region))
    error_message = "The region must be a valid Oracle Cloud (OCI) Region name (e.g. us-ashburn-1, us-phoenix-1, uk-london-1)."
  }
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

  validation {
    condition     = var.fingerprint == "" || can(regex("^([a-f0-9]{2}:?){16}$", var.fingerprint))
    error_message = "The API fingerprint must be 16 colon-delimited hex bytes (e.g. 12:34:56:78:90:ab:cd:ef:12:34:56:78:90:ab:cd:ef) or left blank for ORM/Cloud Shell."
  }
}

variable "private_key_path" {
  description = "Path to the API signing private key. Leave blank when using the OCI Cloud Shell or Resource Manager."
  type        = string
  default     = ""
}


variable "ssh_authorized_keys" {
  description = "One or more SSH public keys that should be added to the compute instances."
  type        = string

  validation {
    condition = can(regex("^(ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ssh-ed25519 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp256 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp384 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?|ecdsa-sha2-nistp521 AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?)$", var.ssh_authorized_keys))
    error_message = "SSH public key must be in valid OpenSSH format (ssh-rsa, ssh-ed25519, or ecdsa-sha2-*). Example: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGbPhiQgg... user@hostname'"
  }
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

variable "coolify_ocpus" {
  description = "Number of OCPUs allocated to the Coolify server."
  type        = number
  default     = 2
}

variable "coolify_memory_in_gbs" {
  description = "Memory (in GB) allocated to the Coolify server."
  type        = number
  default     = 12
}

variable "coolify_block_volume_size_in_gbs" {
  description = "Size of the additional block volume attached to the Coolify server."
  type        = number
  default     = 100
}

variable "coolify_custom_tcp_ports" {
  description = "Additional TCP ports that should be opened to the Coolify server."
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
  default     = false
}

variable "deploy_coolify" {
  description = "Deploy Coolify server."
  type        = bool
  default     = true
}

# =============================================================================
# CLOUDFLARE TUNNEL CONFIGURATION (Optional)
# =============================================================================

variable "enable_cloudflare_tunnel" {
  description = "Enable Cloudflare tunnel for secure access to Coolify"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token with Zone:DNS:Edit and Account:Cloudflare Tunnel:Edit permissions"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in dashboard right sidebar)"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain (found in domain dashboard)"
  type        = string
  default     = ""
}

variable "tunnel_hostname" {
  description = "Hostname for Coolify access (e.g., coolify.yourdomain.com)"
  type        = string
  default     = ""

  validation {
    condition     = var.tunnel_hostname == "" || can(regex("^[a-z0-9-]+\\.[a-z0-9.-]+\\.[a-z]{2,}$", var.tunnel_hostname))
    error_message = "Tunnel hostname must be a valid domain format (e.g., coolify.yourdomain.com)."
  }
}

variable "ssh_hostname" {
  description = "Hostname for SSH access (e.g., ssh.yourdomain.com). Leave empty to auto-generate from tunnel_hostname"
  type        = string
  default     = ""
}

# =============================================================================
# SSL CERTIFICATE CONFIGURATION (Alternative to Cloudflare Tunnel)
# =============================================================================

variable "enable_custom_ssl" {
  description = "Enable Cloudflare Origin Certificate deployment"
  type        = bool
  default     = false
}

variable "origin_certificate" {
  description = "Cloudflare Origin Certificate content (PEM format)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "private_key" {
  description = "Certificate private key content (PEM format)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# ANSIBLE TESTING CONFIGURATION
# =============================================================================

variable "skip_ansible_execution" {
  description = "Skip automatic Ansible playbook execution during cloud-init for testing purposes"
  type        = bool
  default     = false
}

# =============================================================================
# COOLIFY ROOT USER CONFIGURATION
# =============================================================================

variable "coolify_root_username" {
  description = "Root username for Coolify admin access"
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{3,30}$", var.coolify_root_username))
    error_message = "Username must be 3-30 characters long and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "coolify_root_user_email" {
  description = "Email address for the Coolify root user (required)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.coolify_root_user_email))
    error_message = "Must be a valid email address format."
  }
}
