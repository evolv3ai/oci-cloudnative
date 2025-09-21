# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OCI quickstart repository originally showcasing MuShop, an e-commerce application demonstrating Oracle Cloud Infrastructure services. The repository has been modified by Codex to implement a **VibeStack-recommended two-server deployment** that maximally utilizes the OCI Always Free tier resources.

**Current Focus**: The `deploy/basic/` directory now contains Terraform configuration for deploying a **KASM Workspaces server** and **Coolify server** within Always Free tier limits, replacing the original MuShop e-commerce application.

### Deployment Models

- **Basic (VibeStack)**: Two-server Terraform deployment using the full Always Free tier allocation (4 OCPUs, 24GB RAM, 160GB storage)
- **Complete**: Original full microservices deployment on Kubernetes with backing services (legacy)

## Architecture

### VibeStack Two-Server Architecture (Primary)

The `deploy/basic/` directory contains Terraform configuration for a **streamlined two-server deployment** that maximizes OCI Always Free tier usage:

| Resource | Specification | Purpose |
|----------|---------------|---------|
| **KASM Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 60GB block volume) | Remote workspace hosting with KASM Workspaces |
| **Coolify Server** | VM.Standard.A1.Flex (2 OCPUs, 12GB RAM, 100GB block volume) | Self-hosted application platform |
| **Shared Network** | VCN (10.0.0.0/16), Public Subnet (10.0.1.0/24), Internet Gateway | Network infrastructure with public access |
| **Security** | TCP ports 22/80/443/3000 + configurable KASM ports | Controlled access with SSH, HTTP(S), and application ports |

**Resource Utilization**: 4/4 OCPUs (100%), 24/24GB RAM (100%), 160/200GB storage (80%)

### Original MuShop Microservices (Legacy)

The `src/` directory contains the original polyglot microservices for reference:

- **api** (Node.js): API orchestration layer for storefront
- **storefront** (Node.js): Frontend SPA built with Gulp/UIKit
- **catalogue** (Go): Product catalog with Autonomous DB integration
- **carts** (Java): Shopping cart service
- **orders** (Java): Order processing with Spring Boot
- **user** (TypeScript): Customer accounts and authentication
- **payment** (Go): Payment processing
- **events** (Go): Event streaming with OCI Streaming
- **fulfillment** (Micronaut): Order fulfillment
- **assets** (Node.js): Static asset management
- **functions** (JavaScript): Serverless functions for newsletters

### Deployment Options

1. **VibeStack Basic** (`deploy/basic/`):
   - **Primary**: Terraform configuration for KASM + Coolify servers
   - Uses full Always Free tier allocation (4 OCPUs, 24GB RAM)
   - Simplified networking with public subnet access
   - Resource Manager stack compatible

2. **Complete Deployment** (`deploy/complete/`):
   - **Legacy**: Original Kubernetes/Helm deployment for MuShop
   - Docker Compose for development
   - Full cloud-native stack with OCI services

## Development Commands

### VibeStack Terraform Deployment (Primary)

**Deploy the two-server stack:**
```bash
cd deploy/basic/terraform

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCI credentials and preferences

# Deploy infrastructure
terraform init
terraform apply

# Show server IPs and access information
terraform output
```

**Key Terraform variables:**
- `availability_domain`: Target AD with A1 capacity
- `assign_public_ip`: Whether to assign public IPs (default: true)
- `kasm_custom_tcp_ports`: Additional ports for KASM (beyond 22/80/443/3000)

**Destroy resources:**
```bash
cd deploy/basic/terraform
terraform destroy
```

### Legacy MuShop Services (Reference)

**API Service:**
```bash
cd src/api
make up          # Start with dependencies
make dev         # Clean start for development
make test        # Run tests in Docker
make clean       # Remove containers
```

**Storefront:**
```bash
cd src/storefront
npm install      # Install dependencies
npm run build    # Production build
npm run lint     # Lint code
npm test         # Run tests
gulp             # Development server
make up          # Docker development setup
```

**Node.js services (api, storefront, assets):**
```bash
npm install
npm test
npm start
```

### Legacy Kubernetes Deployment

**Setup utilities:**
```bash
cd deploy/complete/helm-chart
helm dependency update ./setup
helm install mushop-utilities setup --namespace mushop-utilities --create-namespace
```

**Deploy application:**
```bash
# Quick start (mock mode)
helm install mymushop mushop \
  --namespace mushop \
  --create-namespace \
  --set global.mock.service=all

# Production deployment (requires OCI credentials)
helm install -f myvalues.yaml mymushop mushop
```

### Testing

- **Terraform validation**: `terraform plan` and `terraform validate` in `deploy/basic/terraform/`
- **API tests**: `cd src/api && npm test` (uses Jest)
- **Storefront tests**: `cd src/storefront && npm test` (uses Jest)
- **Docker-based testing**: Most services have Makefiles with `make test` targets
- CI pipeline tests are defined in `wercker.yml`

## Key Configuration

### VibeStack Configuration

**Always Free Tier Constraints:**
- **OCPUs**: Must use 4/4 available Ampere A1 OCPUs (2 per server)
- **Memory**: Must use 24/24 GB available RAM (12 GB per server)
- **Storage**: Uses 160/200 GB block storage (60 GB KASM + 100 GB Coolify)
- **Region**: Resources must be deployed in your home region
- **Availability Domain**: Must target AD with A1 capacity

**Network Security:**
- **Public access**: Enabled by default for both servers
- **Inbound ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3000 (Coolify UI)
- **KASM ports**: Configurable via `kasm_custom_tcp_ports` variable
- **Outbound**: All traffic permitted for updates/packages

**Terraform Variables:**
- `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`: OCI API credentials
- `region`: Target OCI region
- `compartment_ocid`: Target compartment
- `availability_domain`: Specific AD with A1 capacity
- `assign_public_ip`: Whether to assign public IPs (default: true)
- `kasm_custom_tcp_ports`: Additional TCP ports for KASM server

### Legacy MuShop Configuration

**Service Dependencies** (legacy):
Services communicate through environment variables defining service URLs:
- `CATALOGUE_URL=http://catalogue`
- `CARTS_URL=http://carts`
- `ORDERS_URL=http://orders`
- `USERS_URL=http://user`

**Database Integration** (legacy):
Services use Oracle Autonomous Database (ATP) with wallet-based authentication:
- Wallet files stored in Kubernetes secrets
- Connection details in `oadb-connection` secrets
- Separate databases can be provisioned per service

**OCI Service Integration** (legacy):
- **Streaming**: Events service integrates with OCI Streaming
- **Functions**: Newsletter subscription uses OCI Functions + API Gateway
- **Object Storage**: Asset management
- **Service Broker**: Automated OCI resource provisioning

## File Structure Conventions

Each service follows this pattern:
```
src/[service]/
├── Dockerfile          # Container build
├── VERSION             # Semantic version
├── PLATFORMS           # Target architectures (optional)
├── package.json        # Node.js dependencies (if applicable)
├── Makefile           # Development commands (some services)
└── [source files]
```

## Build Process

- **Container Images**: Each service has a Dockerfile for building container images
- **CI/CD**: Wercker-based pipeline builds and pushes to Oracle Container Registry
- **Versioning**: VERSION files control semantic versioning
- **Multi-arch**: PLATFORMS files specify target architectures (amd64/arm64)

## Development Workflow

### VibeStack Workflow (Primary)

1. **Configure Terraform**: Edit `deploy/basic/terraform/terraform.tfvars` with OCI credentials
2. **Deploy infrastructure**: Run `terraform init && terraform apply` from `deploy/basic/terraform/`
3. **Access servers**: Use output IPs to SSH into KASM and Coolify servers
4. **Configure applications**: Set up KASM Workspaces and Coolify on respective servers
5. **Teardown**: Run `terraform destroy` to remove all resources

### Legacy MuShop Workflow

1. Use Docker/Make commands for local service development
2. Test individual services with their respective test commands
3. Use helm charts for full stack development on Kubernetes
4. Leverage mock mode for development without cloud dependencies

## Important Notes

- **Always Free Focus**: The primary purpose is now VibeStack deployment, not MuShop e-commerce
- **Resource Limits**: Deployment maximizes Always Free tier usage (4 OCPUs, 24GB RAM)
- **Regional Constraint**: Always Free resources only available in home region
- **Capacity Issues**: A1 capacity may be limited; retry deployment or try different ADs
- **Legacy Code**: The `src/` microservices remain for reference but are not part of the VibeStack deployment