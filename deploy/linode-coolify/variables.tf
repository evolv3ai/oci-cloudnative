# =============================================================================
# LINODE AUTHENTICATION
# =============================================================================

variable "linode_token" {
  description = "Linode API Token (Personal Access Token from Linode dashboard)"
  type        = string
  sensitive   = true
}

# =============================================================================
# INSTANCE CONFIGURATION
# =============================================================================

variable "region" {
  description = "Linode region for deployment (e.g., us-east, eu-west)"
  type        = string
  default     = "us-east"
}

variable "instance_type" {
  description = "Linode instance type (e.g., g6-nanode-1, g6-standard-1)"
  type        = string
  default     = "g6-standard-2"  # 4GB RAM, 2 CPU cores
}

variable "image" {
  description = "Linode image to use"
  type        = string
  default     = "linode/ubuntu22.04"
}

variable "instance_label" {
  description = "Label for the Linode instance"
  type        = string
  default     = "coolify-server"
}

variable "root_pass" {
  description = "Root password for the Linode instance"
  type        = string
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "SSH public key(s) for instance access (one per line)"
  type        = string
}

# =============================================================================
# STORAGE CONFIGURATION
# =============================================================================

variable "block_storage_size" {
  description = "Size of block storage volume in GB (10-10240)"
  type        = number
  default     = 100

  validation {
    condition     = var.block_storage_size >= 10 && var.block_storage_size <= 10240
    error_message = "Block storage size must be between 10 and 10240 GB."
  }
}

# =============================================================================
# COOLIFY CONFIGURATION
# =============================================================================

variable "coolify_root_username" {
  description = "Coolify root user username"
  type        = string
  default     = "admin"
}

variable "coolify_root_email" {
  description = "Coolify root user email"
  type        = string
}

variable "coolify_root_password" {
  description = "Coolify root user password"
  type        = string
  sensitive   = true
}

# =============================================================================
# CLOUDFLARE TUNNEL CONFIGURATION
# =============================================================================

variable "enable_cloudflare_tunnel" {
  description = "Enable Cloudflare tunnel for secure access to Coolify"
  type        = bool
  default     = true
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

# =============================================================================
# ADVANCED OPTIONS
# =============================================================================

variable "skip_ansible_execution" {
  description = "Skip automatic Ansible execution for testing (advanced users only)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to Linode resources"
  type        = list(string)
  default     = ["coolify", "vibestack"]
}
