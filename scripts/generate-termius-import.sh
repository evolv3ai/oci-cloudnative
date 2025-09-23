#!/bin/bash

# VibeStack Termius Import Generator
# Generates import files for Termius SSH client from Terraform outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 VibeStack Termius Import Generator${NC}"
echo "======================================"

# Load environment variables if .env exists
if [ -f .env ]; then
    echo -e "${YELLOW}Loading configuration from .env file...${NC}"
    export $(cat .env | grep -v '^#' | xargs)
fi

# Set defaults from environment or use standard values
SSH_USERNAME="${SSH_USERNAME:-ubuntu}"
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/id_rsa}"
OUTPUT_DIR="${OUTPUT_DIR:-./termius-import}"
TERRAFORM_DIR="${TERRAFORM_DIR:-./terraform/vibestack}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to extract values from terraform output
get_terraform_output() {
    # Check if we're using a log file instead of live terraform
    if [ -n "$VIBESTACK_LOG_FILE" ] && [ -f "$VIBESTACK_LOG_FILE" ]; then
        echo -e "${YELLOW}Using log file: $(basename "$VIBESTACK_LOG_FILE")${NC}"

        # Extract outputs from log file
        if grep -q '"outputs"' "$VIBESTACK_LOG_FILE"; then
            # Full terraform state - extract outputs section
            grep -A 1000 '"outputs"' "$VIBESTACK_LOG_FILE" | head -n -5
        else
            # Assume it's already the outputs section
            cat "$VIBESTACK_LOG_FILE"
        fi
    else
        # Standard terraform output
        cd "$TERRAFORM_DIR"
        terraform output -json 2>/dev/null || echo "{}"
    fi
}

echo "Fetching Terraform outputs..."
TF_OUTPUT=$(get_terraform_output)

# Check if terraform output is valid
if [ "$TF_OUTPUT" = "{}" ]; then
    echo -e "${RED}❌ Error: No Terraform outputs found!${NC}"
    echo "Please ensure you have run 'terraform apply' in $TERRAFORM_DIR"
    exit 1
fi

# Extract server information
KASM_IP=$(echo "$TF_OUTPUT" | jq -r '.kasm_server.value.public_ip // empty')
COOLIFY_IP=$(echo "$TF_OUTPUT" | jq -r '.coolify_server.value.public_ip // empty')
KASM_PRIVATE_IP=$(echo "$TF_OUTPUT" | jq -r '.kasm_server.value.private_ip // empty')
COOLIFY_PRIVATE_IP=$(echo "$TF_OUTPUT" | jq -r '.coolify_server.value.private_ip // empty')
COMPARTMENT_NAME=$(echo "$TF_OUTPUT" | jq -r '.compartment.value.name // "vibestack"')

# Determine which servers are deployed
SERVERS_DEPLOYED=""
if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    SERVERS_DEPLOYED="${SERVERS_DEPLOYED}kasm "
    echo -e "${GREEN}✓ KASM Server found: $KASM_IP${NC}"
fi
if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    SERVERS_DEPLOYED="${SERVERS_DEPLOYED}coolify "
    echo -e "${GREEN}✓ Coolify Server found: $COOLIFY_IP${NC}"
fi

if [ -z "$SERVERS_DEPLOYED" ]; then
    echo -e "${RED}❌ No servers found in Terraform output!${NC}"
    exit 1
fi

# Generate CSV file
echo -e "\n${YELLOW}Generating CSV import file...${NC}"
cat > "$OUTPUT_DIR/vibestack-termius.csv" << EOF
Groups,Label,Tags,Hostname/IP,Protocol,Port
EOF

if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    echo "VibeStack OCI - $COMPARTMENT_NAME,KASM-server-$COMPARTMENT_NAME,\"vibestack,kasm,oci\",$KASM_IP,ssh,$SSH_PORT" >> "$OUTPUT_DIR/vibestack-termius.csv"
fi

if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    echo "VibeStack OCI - $COMPARTMENT_NAME,Coolify-server-$COMPARTMENT_NAME,\"vibestack,coolify,oci\",$COOLIFY_IP,ssh,$SSH_PORT" >> "$OUTPUT_DIR/vibestack-termius.csv"
fi

# Generate SSH config file
echo -e "${YELLOW}Generating SSH config file...${NC}"
cat > "$OUTPUT_DIR/vibestack-ssh-config" << EOF
# VibeStack OCI Servers SSH Configuration
# Generated: $(date)
# Compartment: $COMPARTMENT_NAME
# Add this to your ~/.ssh/config file or import via ssh_config format in Termius

EOF

if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    cat >> "$OUTPUT_DIR/vibestack-ssh-config" << EOF
Host ${COMPARTMENT_NAME}-kasm
    HostName $KASM_IP
    User $SSH_USERNAME
    Port $SSH_PORT
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    # KASM Workspaces server (2 OCPUs, 12GB RAM, 60GB storage)
    # Private IP: $KASM_PRIVATE_IP

EOF
fi

if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    cat >> "$OUTPUT_DIR/vibestack-ssh-config" << EOF
Host ${COMPARTMENT_NAME}-coolify
    HostName $COOLIFY_IP
    User $SSH_USERNAME
    Port $SSH_PORT
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    # Coolify app platform server (2 OCPUs, 12GB RAM, 100GB storage)
    # Private IP: $COOLIFY_PRIVATE_IP

EOF
fi

# Generate JSON file
echo -e "${YELLOW}Generating JSON import file...${NC}"
cat > "$OUTPUT_DIR/vibestack-termius.json" << EOF
{
  "hosts": [
EOF

FIRST=true
if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    if [ "$FIRST" = false ]; then echo "," >> "$OUTPUT_DIR/vibestack-termius.json"; fi
    cat >> "$OUTPUT_DIR/vibestack-termius.json" << EOF
    {
      "label": "KASM-server-$COMPARTMENT_NAME",
      "address": "$KASM_IP",
      "username": "$SSH_USERNAME",
      "port": $SSH_PORT,
      "tags": ["vibestack", "oci", "kasm", "$COMPARTMENT_NAME"],
      "notes": "KASM Workspaces server - VibeStack deployment\\n2 OCPUs, 12GB RAM, 60GB storage\\nPrivate IP: $KASM_PRIVATE_IP",
      "group": "VibeStack OCI - $COMPARTMENT_NAME"
    }
EOF
    FIRST=false
fi

if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    if [ "$FIRST" = false ]; then echo "," >> "$OUTPUT_DIR/vibestack-termius.json"; fi
    cat >> "$OUTPUT_DIR/vibestack-termius.json" << EOF
    {
      "label": "Coolify-server-$COMPARTMENT_NAME",
      "address": "$COOLIFY_IP",
      "username": "$SSH_USERNAME",
      "port": $SSH_PORT,
      "tags": ["vibestack", "oci", "coolify", "$COMPARTMENT_NAME"],
      "notes": "Coolify app platform server - VibeStack deployment\\n2 OCPUs, 12GB RAM, 100GB storage\\nPrivate IP: $COOLIFY_PRIVATE_IP",
      "group": "VibeStack OCI - $COMPARTMENT_NAME"
    }
EOF
fi

cat >> "$OUTPUT_DIR/vibestack-termius.json" << EOF

  ]
}
EOF

# Generate quick connect script
echo -e "${YELLOW}Generating quick connect script...${NC}"
cat > "$OUTPUT_DIR/connect.sh" << 'CONNECT_SCRIPT'
#!/bin/bash
# Quick connect script for VibeStack servers

echo "VibeStack Server Connection"
echo "=========================="
echo "1) KASM Server"
echo "2) Coolify Server"
echo -n "Select server [1-2]: "
read choice

case $choice in
CONNECT_SCRIPT

if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    cat >> "$OUTPUT_DIR/connect.sh" << EOF
    1)
        echo "Connecting to KASM server ($KASM_IP)..."
        ssh -i $SSH_KEY_PATH -p $SSH_PORT $SSH_USERNAME@$KASM_IP
        ;;
EOF
fi

if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    cat >> "$OUTPUT_DIR/connect.sh" << EOF
    2)
        echo "Connecting to Coolify server ($COOLIFY_IP)..."
        ssh -i $SSH_KEY_PATH -p $SSH_PORT $SSH_USERNAME@$COOLIFY_IP
        ;;
EOF
fi

cat >> "$OUTPUT_DIR/connect.sh" << 'EOF'
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac
EOF

chmod +x "$OUTPUT_DIR/connect.sh"

# Summary
echo -e "\n${GREEN}✅ Import files generated successfully!${NC}"
echo "======================================"
echo -e "Files created in: ${YELLOW}$OUTPUT_DIR/${NC}"
echo ""
echo "📁 Generated files:"
echo "  • vibestack-termius.csv    - CSV format for Termius import"
echo "  • vibestack-termius.json   - JSON format for Termius import"
echo "  • vibestack-ssh-config     - SSH config format"
echo "  • connect.sh               - Quick connect script"
echo ""
echo "🚀 To import in Termius:"
echo "  1. Open Termius"
echo "  2. Go to Settings > Import"
echo "  3. Select CSV and choose: $OUTPUT_DIR/vibestack-termius.csv"
echo ""
echo "🔗 Quick access URLs:"
if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    echo "  • KASM:    https://$KASM_IP"
fi
if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    echo "  • Coolify: http://$COOLIFY_IP:3000"
fi