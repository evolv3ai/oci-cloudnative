# Oracle Cloud Infrastructure (OCI) Coolify Deployment Guide

This document covers OCI-specific configuration requirements and troubleshooting for deploying Coolify on Oracle Cloud Infrastructure, particularly on Always Free tier ARM instances.

## OCI-Specific Configuration Requirements

### Root User Access Configuration

**Issue**: By default, OCI instances disable root login via SSH, which can cause issues with Coolify deployment.

**Solution**: Enable root access (required for Coolify installation):

```bash
# Switch to root user
sudo su -

# Edit SSH configuration
nano /etc/ssh/sshd_config

# Change the following line:
# From: PermitRootLogin no
# To:   PermitRootLogin without-password

# Restart SSH service
service sshd restart

# Add your public key to root's authorized_keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "your-public-key-here" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

### Non-Root User Configuration (Experimental)

**Note**: Coolify's non-root user support is experimental and may require additional configuration.

If using non-root deployment:

```bash
# Ensure user has sudo privileges
sudo usermod -aG sudo ubuntu

# Add SSH key to user's authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key-here" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## OCI Firewall Configuration

### Instance-Level Firewall

**Issue**: OCI ARM instances have local firewall (iptables/ufw) enabled by default, blocking Coolify ports.

**Solution**: Configure firewall rules for Coolify:

```bash
# Check current firewall status
sudo ufw status

# Allow required Coolify ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 8000/tcp  # Coolify Web Interface
sudo ufw allow 6001/tcp  # Coolify internal (v4.0.0-beta.336+)
sudo ufw allow 6002/tcp  # Coolify internal (v4.0.0-beta.336+)

# Allow Docker network communication
sudo ufw allow from 172.17.0.0/16
sudo ufw allow from 172.18.0.0/16

# Enable firewall if not already enabled
sudo ufw --force enable
```

### OCI Security List Configuration

**Requirement**: OCI Security Lists must allow traffic to Coolify ports.

Our Terraform configuration includes these rules:

```terraform
# Coolify required ports in security list
ingress_security_rules {
  protocol = "6"
  source   = "0.0.0.0/0"
  tcp_options {
    min = 8000
    max = 8000
  }
}

# Additional Coolify internal ports (v4.0.0-beta.336+)
ingress_security_rules {
  protocol = "6"
  source   = "0.0.0.0/0"
  tcp_options {
    min = 6001
    max = 6002
  }
}
```

## OCI Always Free Tier Considerations

### Resource Constraints

- **CPU**: 2 OCPUs per instance (4 total for Free Tier)
- **Memory**: 12 GB RAM per instance (24 GB total)
- **Storage**: 100 GB block volume recommended for Coolify
- **Network**: 10 TB monthly egress included

### Instance Configuration

**Recommended OCI Configuration**:
- **Shape**: VM.Standard.A1.Flex (ARM64)
- **OCPUs**: 2
- **Memory**: 12 GB
- **Boot Volume**: 50 GB (minimum)
- **Block Volume**: 100 GB (for Docker images/containers)

## Deployment Process

### Pre-Installation Steps

1. **Verify SSH Access**:
   ```bash
   ssh ubuntu@<instance-ip>
   sudo su -  # Test root access
   ```

2. **Check Firewall Status**:
   ```bash
   sudo ufw status
   sudo iptables -L
   ```

3. **Verify Network Connectivity**:
   ```bash
   # Test outbound connectivity
   curl -I https://github.com

   # Test DNS resolution
   nslookup coolify.io
   ```

### Coolify Installation

1. **Run Coolify Installation Script**:
   ```bash
   # As root user
   curl -fsSL https://cdn.coolify.io/coolify/install.sh | bash
   ```

2. **Verify Installation**:
   ```bash
   # Check Coolify services
   docker ps

   # Check service logs
   docker logs coolify
   ```

3. **Access Web Interface**:
   - URL: `http://<instance-public-ip>:8000`
   - Default credentials will be displayed in installation output

## Common Issues and Troubleshooting

### Issue: Connection Refused on Port 8000

**Symptoms**: Cannot access Coolify web interface

**Solutions**:
1. Check local firewall:
   ```bash
   sudo ufw status
   sudo ufw allow 8000/tcp
   ```

2. Verify OCI Security List allows port 8000

3. Check Coolify container status:
   ```bash
   docker ps | grep coolify
   docker logs coolify
   ```

### Issue: Docker Permission Denied

**Symptoms**: Docker commands fail with permission errors

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run as root
sudo su -
```

### Issue: Out of Disk Space

**Symptoms**: Docker operations fail due to insufficient space

**Solutions**:
1. Clean Docker system:
   ```bash
   docker system prune -a
   docker volume prune
   ```

2. Monitor disk usage:
   ```bash
   df -h
   du -sh /var/lib/docker
   ```

3. Consider expanding block volume in OCI console

### Issue: Coolify Internal Ports (v4.0.0-beta.336+)

**Symptoms**: Newer Coolify versions require additional ports

**Solution**: Ensure ports 6001 and 6002 are open:
```bash
# Local firewall
sudo ufw allow 6001/tcp
sudo ufw allow 6002/tcp

# Verify OCI Security List includes these ports
```

## Performance Optimization

### Docker Configuration

**Optimize Docker for ARM64**:
```bash
# Create or edit Docker daemon configuration
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
```

### Memory Management

**Monitor resource usage**:
```bash
# Check memory usage
free -h
htop

# Monitor Docker resource usage
docker stats
```

## Security Considerations

### Network Security

1. **Limit SSH Access**:
   ```bash
   # Edit /etc/ssh/sshd_config
   AllowUsers ubuntu root
   PasswordAuthentication no
   PermitEmptyPasswords no
   ```

2. **Configure Fail2Ban**:
   ```bash
   sudo apt update
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

3. **Regular Updates**:
   ```bash
   # Schedule automatic security updates
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

### Coolify Security

1. **Change Default Credentials**: Immediately change default admin credentials after installation

2. **Enable HTTPS**: Configure SSL certificates through Coolify interface

3. **Backup Configuration**: Regularly backup Coolify configuration and databases

## Monitoring and Maintenance

### Health Checks

Create a monitoring script:
```bash
#!/bin/bash
# coolify-health-check.sh

# Check Coolify container
if ! docker ps | grep -q coolify; then
    echo "ERROR: Coolify container not running"
    exit 1
fi

# Check web interface
if ! curl -sf http://localhost:8000 > /dev/null; then
    echo "ERROR: Coolify web interface not accessible"
    exit 1
fi

echo "Coolify is healthy"
```

### Log Management

```bash
# View Coolify logs
docker logs coolify --tail 50 -f

# Rotate Docker logs
docker system prune --volumes
```

## Integration with OCI Services

### OCI Object Storage

Configure Coolify to use OCI Object Storage for backups:
1. Create OCI Object Storage bucket
2. Configure storage credentials in Coolify
3. Set up automated backup schedules

### OCI Load Balancer

For production deployments, consider adding OCI Load Balancer:
- Terminate SSL at load balancer
- Distribute traffic across multiple Coolify instances
- Health check configuration for high availability

## Version-Specific Notes

### Coolify v4.0.0-beta.336+

**New Requirements**:
- Additional ports 6001 and 6002 required
- Updated internal networking configuration
- Enhanced security features

**Migration Steps**:
1. Update firewall rules for new ports
2. Update OCI Security Lists
3. Restart Coolify after upgrade

This guide should be referenced alongside the main VibeStack deployment documentation in CLAUDE.md for complete OCI Coolify deployment coverage.