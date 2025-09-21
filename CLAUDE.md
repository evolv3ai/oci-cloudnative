# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MuShop is a showcase e-commerce application demonstrating Oracle Cloud Infrastructure services through a microservices architecture. The application has two deployment models:

- **Basic**: Simple deployment using only Always Free tier resources (Terraform-based)
- **Complete**: Full microservices deployment on Kubernetes with backing services

## Architecture

### Microservices Structure

The application follows a polyglot microservices architecture with services in `src/`:

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

1. **Basic Deployment** (`deploy/basic/`):
   - Terraform-based deployment
   - Uses Oracle Resource Manager stacks
   - Always Free tier compatible

2. **Complete Deployment** (`deploy/complete/`):
   - Kubernetes/Helm deployment
   - Docker Compose for development
   - Full cloud-native stack with OCI services

## Development Commands

### Individual Services

Most services use Docker for development. Common patterns:

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

### Kubernetes Deployment

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

- **API tests**: `cd src/api && npm test` (uses Jest)
- **Storefront tests**: `cd src/storefront && npm test` (uses Jest)
- **Docker-based testing**: Most services have Makefiles with `make test` targets
- CI pipeline tests are defined in `wercker.yml`

## Key Configuration

### Service Dependencies

Services communicate through environment variables defining service URLs:
- `CATALOGUE_URL=http://catalogue`
- `CARTS_URL=http://carts`
- `ORDERS_URL=http://orders`
- `USERS_URL=http://user`

### Database Integration

Services use Oracle Autonomous Database (ATP) with wallet-based authentication:
- Wallet files stored in Kubernetes secrets
- Connection details in `oadb-connection` secrets
- Separate databases can be provisioned per service

### OCI Service Integration

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

1. Use Docker/Make commands for local service development
2. Test individual services with their respective test commands
3. Use helm charts for full stack development on Kubernetes
4. Leverage mock mode for development without cloud dependencies