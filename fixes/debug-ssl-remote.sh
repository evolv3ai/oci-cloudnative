#!/bin/bash
# Quick SSH test script for Coolify instance SSL debugging

INSTANCE_IP="132.145.166.93"
SSH_KEY="C:/Users/Owner/.ssh/my-oci-devops"
SSH_USER="ubuntu"

echo "Connecting to Coolify instance at $INSTANCE_IP..."

# Convert Windows path to WSL/Git Bash compatible path if needed
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    SSH_KEY="/c/Users/Owner/.ssh/my-oci-devops"
fi

# SSH command to check SSL certificate status
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$INSTANCE_IP" << 'EOF'
echo "=== Checking SSL Certificate Installation ==="
echo ""

echo "1. Checking for SSL files in /opt/vibestack/:"
sudo ls -la /opt/vibestack/ssl* 2>/dev/null || echo "No SSL files found"
echo ""

echo "2. Checking certificate validity:"
if [ -f /opt/vibestack/ssl.cert ]; then
    sudo openssl x509 -in /opt/vibestack/ssl.cert -noout -text | head -20
else
    echo "Certificate file not found"
fi
echo ""

echo "3. Checking private key:"
if [ -f /opt/vibestack/ssl.key ]; then
    sudo openssl rsa -in /opt/vibestack/ssl.key -check -noout 2>&1
else
    echo "Private key file not found"
fi
echo ""

echo "4. Checking Coolify certificate directory:"
sudo docker exec coolify ls -la /data/coolify/proxy/certs/ 2>/dev/null || echo "Coolify not running or certs dir not found"
echo ""

echo "5. Recent SSL-related log entries:"
sudo grep -i "ssl\|cert\|key" /var/log/vibestack-setup.log | tail -20
echo ""

echo "6. Checking for base64 encoded files:"
sudo ls -la /opt/vibestack/*.b64 2>/dev/null || echo "No .b64 files found (good - they should be cleaned up)"
EOF
