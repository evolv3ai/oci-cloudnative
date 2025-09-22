# Oracle Cloud Deploy Button Implementation Specification

## Overview
This specification outlines the requirements for implementing a "Deploy to Oracle Cloud" button that will enable one-click deployment of the Vibestack infrastructure (Coolify and KASM servers) using OCI's Resource Manager.

## Core Requirements

### 1. Package Structure
- **Format**: ZIP file containing Terraform configuration files
- **Files Required**:
  - `main.tf` - Primary resource definitions
  - `variables.tf` - Input variable declarations
  - `outputs.tf` - Output value declarations
  - `provider.tf` - OCI provider configuration
  - `schema.yaml` (optional) - For custom Resource Manager UI

### 2. Hosting Requirements
- **Supported Platforms**:
  - GitHub repository (public)
  - GitLab repository (public)
  - OCI Object Storage with pre-authenticated request URL
- **URL Format**:
  - Direct: `https://github.com/{owner}/{repo}/archive/{branch}.zip`
  - Release: `https://github.com/{owner}/{repo}/archive/{version}.zip`

### 3. Button Implementation

#### Markdown Format
```markdown
[![Deploy to Oracle Cloud](https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl={YOUR_ZIP_URL})
```

#### HTML Format
```html
<a href="https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl={YOUR_ZIP_URL}" target="_blank">
  <img src="https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg" alt="Deploy to Oracle Cloud"/>
</a>
```

## Terraform Configuration Requirements

### 1. Provider Configuration
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = ">= 5.10.0"
    }
  }
}
```

### 2. Resource Definitions for Free Tier

#### Coolify Server Specifications
- **Instance Shape**: VM.Standard.E2.1.Micro or VM.Standard.A1.Flex
- **OCPUs**: 2
- **Memory**: 12 GB
- **Boot Volume**: 100 GB
- **Operating System**: Ubuntu 22.04 or Oracle Linux

#### KASM Server Specifications
- **Instance Shape**: VM.Standard.E2.1.Micro or VM.Standard.A1.Flex
- **OCPUs**: 2
- **Memory**: 12 GB
- **Boot Volume**: 70 GB
- **Operating System**: Ubuntu 22.04 or Oracle Linux

### 3. Variable Configuration
Variables must be defined for user customization:
```hcl
variable "compartment_ocid" {
  description = "Compartment where resources will be created"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain for instances"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key for instance access"
  type        = string
}
```

## Security Considerations

### Do NOT Include:
- Private keys or passwords
- API keys or tokens
- Sensitive configuration data
- Hard-coded credentials

### Best Practices:
- Use OCI Dynamic Groups and Policies for permissions
- Implement principle of least privilege
- Use Resource Manager variables for user-specific data
- Enable encryption for boot volumes

## Deployment Workflow

1. **User Actions**:
   - Click "Deploy to Oracle Cloud" button
   - Sign in to OCI Console
   - Configure stack name and description
   - Select Terraform version
   - Input required variables
   - Review and create stack
   - Apply stack to provision resources

2. **Automated Process**:
   - Resource Manager downloads ZIP file
   - Validates Terraform configuration
   - Creates execution plan
   - Provisions infrastructure on approval
   - Outputs connection details

## Post-Deployment Configuration

### Cloud-Init Integration
Use cloud-init scripts for automated software installation:
```yaml
#cloud-config
packages:
  - docker
  - docker-compose
runcmd:
  - curl -fsSL https://coolify.io/install.sh | bash
```

### Output Values
Provide essential connection information:
```hcl
output "coolify_server_ip" {
  value = oci_core_instance.coolify.public_ip
}

output "kasm_server_ip" {
  value = oci_core_instance.kasm.public_ip
}
```

## Implementation Checklist

- [ ] Create Terraform configuration files
- [ ] Configure free-tier compatible resources
- [ ] Implement variable declarations with defaults
- [ ] Add cloud-init scripts for software installation
- [ ] Create comprehensive outputs
- [ ] Package as ZIP file
- [ ] Upload to GitHub/GitLab
- [ ] Generate deploy button URL
- [ ] Test deployment process
- [ ] Document user instructions

## Constraints & Limitations

1. **Free Tier Limits**:
   - Maximum 2 instances (AMD) or up to 4 ARM instances
   - 200 GB total block volume storage
   - 10 TB outbound data transfer per month

2. **Technical Constraints**:
   - Terraform versions are not backward compatible
   - Users need appropriate IAM permissions
   - Stack creation requires active OCI account
   - Resources must be in allowed regions for free tier

## Success Criteria

- One-click deployment with minimal user input
- Automatic provisioning of both servers
- Software pre-installed and configured
- Clear output of access credentials
- Total deployment time under 10 minutes
- Zero manual SSH or CLI requirements for users