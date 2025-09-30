#!/bin/bash
# Quick sync script for Ansible testing

# Get latest IP from env files
ENV_FILE=$(ls -t scripts/logs/*.env 2>/dev/null | head -1)

if [ -z "$ENV_FILE" ]; then
    echo "No deployment env file found in scripts/logs/"
    exit 1
fi

# Extract IPs
KASM_IP=$(grep "KASM_PUBLIC_IP" "$ENV_FILE" | cut -d'=' -f2)
COOLIFY_IP=$(grep "COOLIFY_PUBLIC_IP" "$ENV_FILE" | cut -d'=' -f2)

# SSH key path
SSH_KEY="C:\Users\Owner\.ssh\my-oci-devops"

# Function to sync ansible files
sync_ansible() {
    local server=$1
    local ip=$2
    
    if [ -n "$ip" ]; then
        echo "Syncing to $server server at $ip..."
        rsync -avz --delete \
            -e "ssh -i $SSH_KEY" \
            ./ansible/ ubuntu@$ip:/opt/vibestack/
        echo "Sync complete! SSH with: ssh -i $SSH_KEY ubuntu@$ip"
    else
        echo "$server server not found in deployment"
    fi
}

# Main menu
echo "VibeStack Ansible Sync Tool"
echo "==========================="
echo "1) Sync to KASM server ($KASM_IP)"
echo "2) Sync to Coolify server ($COOLIFY_IP)"
echo "3) Sync to both servers"
echo "4) Show SSH commands"
read -p "Choice: " choice

case $choice in
    1) sync_ansible "KASM" "$KASM_IP" ;;
    2) sync_ansible "Coolify" "$COOLIFY_IP" ;;
    3) 
        sync_ansible "KASM" "$KASM_IP"
        sync_ansible "Coolify" "$COOLIFY_IP"
        ;;
    4)
        [ -n "$KASM_IP" ] && echo "KASM: ssh -i $SSH_KEY ubuntu@$KASM_IP"
        [ -n "$COOLIFY_IP" ] && echo "Coolify: ssh -i $SSH_KEY ubuntu@$COOLIFY_IP"
        ;;
    *) echo "Invalid choice" ;;
esac