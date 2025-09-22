# Oracle Cloud Free Tier - Recommended Two-Server Setup

## Overview
This configuration runs two servers (KASM and Coolify) entirely within Oracle Cloud's Always Free tier limits, ensuring no charges indefinitely.

## Server Specifications

### Server 1: KASM Server
- **Compute**: 2 OCPUs (Arm-based Ampere A1)
- **Memory**: 12 GB RAM
- **Storage**: 60 GB block volume
- **OS**: Oracle Linux or Ubuntu (recommended)

### Server 2: Coolify Server
- **Compute**: 2 OCPUs (Arm-based Ampere A1)
- **Memory**: 12 GB RAM
- **Storage**: 100 GB block volume
- **OS**: Oracle Linux or Ubuntu (recommended)

### Total Resource Usage
- **OCPUs**: 4 of 4 available (100% utilization)
- **RAM**: 24 GB of 24 GB available (100% utilization)
- **Block Storage**: 160 GB of 200 GB available (80% utilization)

## Networking Architecture

### Virtual Cloud Network (VCN)
```
VCN Name: free-tier-vcn
CIDR Block: 10.0.0.0/16
DNS Resolution: Enabled
```

### Subnet Configuration
```
Subnet Name: public-subnet-1
CIDR Block: 10.0.1.0/24
Type: Public (with Internet Gateway)
Availability Domain: Choose based on capacity
```

### Internet Gateway
```
Name: free-tier-igw
Attached to: free-tier-vcn
Purpose: Provides internet access for both instances
```

### Route Table
```
Destination CIDR: 0.0.0.0/0
Target: Internet Gateway (free-tier-igw)
```

### Security List Rules

#### Ingress Rules
| Source | Protocol | Port Range | Description |
|--------|----------|------------|-------------|
| 0.0.0.0/0 | TCP | 22 | SSH Access |
| 0.0.0.0/0 | TCP | 80 | HTTP |
| 0.0.0.0/0 | TCP | 443 | HTTPS |
| 0.0.0.0/0 | TCP | 3000 | Coolify UI (adjust as needed) |
| 0.0.0.0/0 | TCP | Custom | KASM-specific ports |

#### Egress Rules
| Destination | Protocol | Port Range | Description |
|-------------|----------|------------|-------------|
| 0.0.0.0/0 | All | All | Allow all outbound traffic |

## Implementation Steps

### Step 1: Create VCN
1. Navigate to Networking → Virtual Cloud Networks
2. Click "Create VCN"
3. Enter name: `free-tier-vcn`
4. CIDR block: `10.0.0.0/16`
5. DNS Resolution: Check "Use DNS hostnames"

### Step 2: Create Public Subnet
1. Within the VCN, click "Create Subnet"
2. Name: `public-subnet-1`
3. CIDR block: `10.0.1.0/24`
4. Route Table: Select default route table
5. Subnet Access: Public
6. Security List: Use default or create custom

### Step 3: Create Internet Gateway
1. Click "Internet Gateways" in VCN resources
2. Create Internet Gateway named `free-tier-igw`
3. Add route rule to default route table:
   - Destination: `0.0.0.0/0`
   - Target: Internet Gateway

### Step 4: Launch KASM Instance
1. Navigate to Compute → Instances
2. Click "Create Instance"
3. Name: `KASM-server`
4. Shape: VM.Standard.A1.Flex
5. OCPUs: 2
6. Memory: 12 GB
7. Boot Volume: Default size
8. Add block volume: 60 GB
9. VCN: `free-tier-vcn`
10. Subnet: `public-subnet-1`
11. Assign public IPv4 address: Yes

### Step 5: Launch Coolify Instance
1. Repeat Step 4 with:
   - Name: `coolify-server`
   - OCPUs: 2
   - Memory: 12 GB
   - Block volume: 100 GB

### Step 6: Configure Security Lists
1. Update security list with required ingress rules
2. Ensure SSH (22) is open for initial configuration
3. Open application-specific ports as needed

## Optional Free Tier Services

### Load Balancer (if needed)
- **Type**: Flexible Load Balancer
- **Bandwidth**: 10 Mbps
- **Use case**: Distribute traffic between servers

### Monitoring & Alerts
- **Monitoring**: 500M ingestion datapoints free
- **Notifications**: 1000 emails/month free
- **Logging**: 10 GB/month free

### Backup Strategy
- **Block Volume Backups**: 5 backups included free
- **Object Storage**: 20 GB total (Standard + Infrequent + Archive)

## Cost Optimization Tips

1. **Reserved Capacity**: Since you're using 100% of Ampere A1 resources, monitor availability in your region
2. **Storage Efficiency**: You have 40 GB unused block storage for future expansion
3. **Data Transfer**: Stay within 10 TB/month outbound (very generous limit)
4. **Monitoring**: Set up alerts to ensure instances stay within free tier limits

## Important Notes

- **Region Selection**: Choose your home region during signup - Always Free resources are only available there
- **Availability**: If you see "out of host capacity" errors, try different availability domains or wait and retry
- **Persistence**: Always Free resources won't be reclaimed after trial period ends
- **Support**: Community support only for Always Free tier; upgrade to paid for Oracle Support

## Verification Checklist

- [ ] Total OCPUs ≤ 4 for Ampere A1
- [ ] Total RAM ≤ 24 GB for Ampere A1
- [ ] Total block storage ≤ 200 GB
- [ ] Using only 1 VCN (2 available)
- [ ] Using only 1 Load Balancer if needed
- [ ] All resources in home region
- [ ] Security lists properly configured
- [ ] Public IPs assigned to instances

This configuration maximizes your free tier allocation while providing robust infrastructure for both servers.