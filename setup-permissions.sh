#!/bin/bash

# VibeStack Permission Setup
# Sets correct executable permissions for scripts

echo "🔧 Setting up VibeStack script permissions..."

# Make scripts executable
chmod +x generate-termius-import.sh
chmod +x manage-deployment-logs.sh
chmod +x setup-permissions.sh

# Check if termius-import directory exists and set permissions
if [ -d "termius-import" ]; then
    chmod +x termius-import/connect.sh 2>/dev/null || true
fi

# Check if logs directory exists and set permissions
if [ -d "logs" ]; then
    chmod +x logs/connect.sh 2>/dev/null || true
fi

echo "✅ Permissions set:"
echo "  ✓ generate-termius-import.sh"
echo "  ✓ manage-deployment-logs.sh"
echo "  ✓ setup-permissions.sh"

if [ -f "termius-import/connect.sh" ]; then
    echo "  ✓ termius-import/connect.sh"
fi

echo ""
echo "🚀 Ready to use! Try:"
echo "  ./manage-deployment-logs.sh show-paths"