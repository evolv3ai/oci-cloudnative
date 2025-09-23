#!/bin/bash

# Coolify Installation Script for OCI ARM64 Instance
# Based on the Ansible playbook configuration

set -e

echo "🚀 Starting Coolify Installation on OCI ARM64 Instance"
echo "=================================================="

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    git \
    wget

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker packages
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add current user to docker group
    sudo usermod -aG docker $USER

    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Coolify
echo "🚀 Installing Coolify..."
if [ ! -d "/data/coolify" ]; then
    curl -fsSL https://get.coolify.io | sudo bash
    echo "✅ Coolify installation script executed"
else
    echo "✅ Coolify already installed"
fi

# Wait for Coolify to start
echo "⏳ Waiting for Coolify to start (this may take a few minutes)..."
for i in {1..30}; do
    if nc -z localhost 8000 2>/dev/null; then
        echo "✅ Coolify is running!"
        break
    fi
    echo "  Waiting... ($i/30)"
    sleep 10
done

# Display access information
echo ""
echo "=================================================="
echo "✅ Coolify Installation Complete!"
echo "=================================================="
echo ""
echo "🌐 Public Access: http://$(curl -s ifconfig.me):8000"
echo "🔒 Local Access: http://$(hostname -I | awk '{print $1}'):8000"
echo ""
echo "📝 Next Steps:"
echo "1. Open the Coolify web interface in your browser"
echo "2. Complete the initial setup wizard"
echo "3. Configure your first application"
echo ""
echo "Note: You may need to log out and back in for Docker group changes to take effect"