# VibeStack Ansible Testing Workflow

## Quick Start

Deploy without auto-running Ansible for testing:
```bash
cd deploy/kasm
terraform apply
# SSH in and test manually
```

## Efficient Testing Loop

### 1. Deploy Once
```bash
terraform apply  # Creates instance with Ansible ready but not executed
```

### 2. Get Instance IP
```bash
# Check scripts/logs/ for latest .env file with IPs
cat scripts/logs/$(ls -t scripts/logs/*.env | head -1)
```

### 3. Fast Iteration Methods

**Method A: Direct Sync (Fastest)**
```bash
# Sync local changes to instance
rsync -avz -e "ssh -i C:\Users\Owner\.ssh\my-oci-devops" \
  ./ansible/ ubuntu@<IP>:/opt/vibestack-ansible/

# SSH and test
ssh -i C:\Users\Owner\.ssh\my-oci-devops ubuntu@<IP>
sudo ansible-playbook /opt/vibestack-ansible/kasm/install.yml
```

**Method B: Clean Reset**
```bash
# On instance - remove previous attempt
sudo docker stop $(sudo docker ps -aq) 2>/dev/null
sudo docker rm $(sudo docker ps -aq) 2>/dev/null
sudo rm -rf /opt/kasm/*

# Re-run
sudo ansible-playbook /opt/vibestack-ansible/kasm/install.yml
```

## Branch Strategy

```bash
# Create test branch
git checkout -b test-ansible

# In deploy/kasm/cloud-init-kasm.yaml, comment out:
# - cd /opt/vibestack-ansible && ansible-playbook kasm/install.yml

# Test until perfect
# Then uncomment and merge to main
```

## Verification

```bash
# Check containers
sudo docker ps | grep kasm

# Check credentials
cat /opt/kasm/credentials.txt

# Test health
sudo /usr/local/bin/kasm-health-check
```

## Same for Coolify

Apply identical process to deploy/coolify/
