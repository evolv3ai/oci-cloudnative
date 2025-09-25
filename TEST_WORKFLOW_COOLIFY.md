# VibeStack Coolify Testing Workflow

## Quick Start

Deploy Coolify without auto-execution:
```bash
cd deploy/coolify
terraform apply
# SSH in and test manually
```

## Testing Loop

### 1. Deploy Once
```bash
terraform apply  # Creates instance with Ansible ready but not executed
```

### 2. Get Instance IP
```bash
# Check scripts/logs/ for latest .env file
cat scripts/logs/$(ls -t scripts/logs/*.env | head -1) | grep COOLIFY_IP
```

### 3. Fast Iteration

**Sync and Test:**
```bash
# Sync changes
rsync -avz -e "ssh -i C:\Users\Owner\.ssh\my-oci-devops" \
  ./ansible/ ubuntu@<IP>:/opt/vibestack-ansible/

# SSH and run
ssh -i C:\Users\Owner\.ssh\my-oci-devops ubuntu@<IP>
sudo ansible-playbook /opt/vibestack-ansible/coolify/install.yml
```

**Clean Reset:**
```bash
# Remove Coolify
sudo systemctl stop coolify
sudo docker stop $(sudo docker ps -aq) 2>/dev/null
sudo docker rm $(sudo docker ps -aq) 2>/dev/null
sudo rm -rf /data/coolify/*

# Re-install
sudo ansible-playbook /opt/vibestack-ansible/coolify/install.yml
```

## Verification

```bash
# Check Coolify service
sudo systemctl status coolify

# Check Docker
sudo docker ps

# Test web interface
curl -I http://localhost:8000

# View logs
sudo journalctl -u coolify -n 50
```

## Key Differences from KASM

- Coolify uses systemd service
- Default port 8000 (not 443)
- Simpler container structure
- No offline installer needed
