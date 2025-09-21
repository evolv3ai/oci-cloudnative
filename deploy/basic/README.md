# OCI Always Free two-server deployment

This Terraform configuration provisions the VibeStack-recommended two-server layout entirely within the Oracle Cloud Infrastructure (OCI) Always Free tier. The stack creates a shared virtual network, one KASM Workspaces server, and one Coolify server so that you can host remote workspaces and self-hosted applications on separate instances while staying within free-tier limits.

## Architecture overview

The deployment creates the following resources:

| Resource | Shape / Size | Purpose |
| --- | --- | --- |
| Virtual Cloud Network (`free-tier-vcn`) | 10.0.0.0/16 | Shared network for both servers |
| Public Subnet (`public-subnet-1`) | 10.0.1.0/24 | Houses the compute instances and exposes them through an Internet Gateway |
| Internet Gateway (`free-tier-igw`) | — | Provides outbound and inbound internet connectivity |
| Route Table | 0.0.0.0/0 → Internet Gateway | Sends all traffic through the gateway |
| Security List | TCP 22/80/443/3000 + optional KASM ports | Restricts ingress to the documented ports, allows all egress |
| KASM server | VM.Standard.A1.Flex – 2 OCPUs / 12 GB RAM | Hosts KASM Workspaces; receives a 60 GB block volume |
| Coolify server | VM.Standard.A1.Flex – 2 OCPUs / 12 GB RAM | Hosts Coolify; receives a 100 GB block volume |

The defaults consume the full Always Free compute allotment (4 OCPUs and 24 GB RAM) and 160 GB of block storage (out of the 200 GB allowance).

### Security rules

Inbound TCP traffic is allowed on:

- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3000 (Coolify UI)
- Any additional KASM ports that you specify via `kasm_custom_tcp_ports`

All outbound traffic is permitted so that both servers can reach external services for updates and package downloads.

## Prerequisites

- Terraform 1.3 or newer
- OCI account with Always Free tier enabled
- Access to a compartment with available Always Free compute and block volume capacity
- At least one SSH public key for administrator access

## Usage

1. Change into the Terraform directory:
   ```shell
   cd deploy/basic/terraform
   ```
2. Copy the example variables file and edit it with your tenancy details and SSH keys:
   ```shell
   cp terraform.tfvars.example terraform.tfvars
   ${EDITOR:-vi} terraform.tfvars
   ```
3. Initialize Terraform:
   ```shell
   terraform init
   ```
4. Review and apply the plan:
   ```shell
   terraform apply
   ```
5. After `apply` completes, Terraform prints the public IP addresses of both servers under the `kasm_server` and `coolify_server` outputs.

## Customization

All stack parameters are defined in `variables.tf` and surfaced through the Resource Manager schema. Key options include:

- `deployment_label` – Append a suffix to resource names to avoid collisions when running multiple stacks.
- `assign_public_ip` – Disable public IP allocation if you plan to front the instances with a separate load balancer or VPN.
- `kasm_custom_tcp_ports` – Open additional TCP ports for KASM (for example, `[8443, 5000]`).
- `custom_image_ocid` – Provide a custom image if you prefer Ubuntu instead of the default Oracle Linux image.

## Clean up

Run `terraform destroy` from the `deploy/basic/terraform` directory to tear down all provisioned resources when you are finished testing.

## Additional resources

- [VibeStack recommended setup](../../docs/oci-vibestack-recommended-setup.md)
- [Oracle Cloud Free Tier resource limits](https://docs.oracle.com/iaas/Content/FreeTier/resourceref.htm)
