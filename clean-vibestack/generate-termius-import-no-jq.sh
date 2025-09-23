#!/bin/bash

# VibeStack Termius Import Generator (No jq required)
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

# Function to extract JSON values using grep and sed (no jq required)
extract_json_value() {
    local json_file="$1"
    local path="$2"

    # Simple JSON extraction using grep and sed
    grep -o "\"$path\"[^,}]*" "$json_file" | sed 's/.*"://' | sed 's/[",]//g' | head -1
}

# Function to extract nested JSON values
extract_nested_value() {
    local json_file="$1"
    local section="$2"
    local field="$3"

    # Look for the field within the specified section context
    # First, find lines with the section, then find the field within reasonable distance
    grep -A 50 "\"$section\"" "$json_file" | grep -m 1 "\"$field\"" | sed 's/.*"'$field'"[[:space:]]*:[[:space:]]*"\?//' | sed 's/[",].*$//' | sed 's/^[[:space:]]*//' | head -1
}

# Function to extract values from terraform output
get_terraform_output() {
    local temp_file="/tmp/terraform_output.json"

    # Check if we're using a log file instead of live terraform
    if [ -n "$VIBESTACK_LOG_FILE" ] && [ -f "$VIBESTACK_LOG_FILE" ]; then
        echo -e "${YELLOW}Using log file: $(basename "$VIBESTACK_LOG_FILE")${NC}"

        # Extract outputs from log file
        if grep -q '"outputs"' "$VIBESTACK_LOG_FILE"; then
            # Full terraform state - extract outputs section
            sed -n '/"outputs"/,/"resources"/p' "$VIBESTACK_LOG_FILE" | head -n -1 > "$temp_file"
        else
            # Assume it's already the outputs section
            cp "$VIBESTACK_LOG_FILE" "$temp_file"
        fi
    else
        # Standard terraform output
        cd "$TERRAFORM_DIR"
        terraform output -json 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"
    fi

    echo "$temp_file"
}

echo "Fetching Terraform outputs..."
TF_OUTPUT_FILE=$(get_terraform_output)

# Check if terraform output is valid
if [ ! -s "$TF_OUTPUT_FILE" ] || [ "$(cat "$TF_OUTPUT_FILE")" = "{}" ]; then
    echo -e "${RED}❌ Error: No Terraform outputs found!${NC}"
    echo "Please ensure you have run 'terraform apply' in $TERRAFORM_DIR"
    exit 1
fi

# Extract server information using simple text processing
KASM_IP=$(extract_nested_value "$TF_OUTPUT_FILE" "kasm_server" "public_ip")
COOLIFY_IP=$(extract_nested_value "$TF_OUTPUT_FILE" "coolify_server" "public_ip")
KASM_PRIVATE_IP=$(extract_nested_value "$TF_OUTPUT_FILE" "kasm_server" "private_ip")
COOLIFY_PRIVATE_IP=$(extract_nested_value "$TF_OUTPUT_FILE" "coolify_server" "private_ip")
COMPARTMENT_NAME=$(extract_nested_value "$TF_OUTPUT_FILE" "compartment" "name")

# Set default compartment name if not found
COMPARTMENT_NAME="${COMPARTMENT_NAME:-vibestack}"

# Determine which servers are deployed
SERVERS_DEPLOYED=""
if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ] && [ "$KASM_IP" != "" ]; then
    SERVERS_DEPLOYED="${SERVERS_DEPLOYED}kasm "
    echo -e "${GREEN}✓ KASM Server found: $KASM_IP${NC}"
fi
if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ] && [ "$COOLIFY_IP" != "" ]; then
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
Label,Tags,Address,Username,Port,Notes
EOF

if [ -n "$KASM_IP" ] && [ "$KASM_IP" != "null" ]; then
    echo "KASM-server-$COMPARTMENT_NAME,\"vibestack oci kasm $COMPARTMENT_NAME\",$KASM_IP,$SSH_USERNAME,$SSH_PORT,\"KASM Workspaces server - VibeStack deployment (2 OCPUs, 12GB RAM, 60GB storage) - Private IP: $KASM_PRIVATE_IP\"" >> "$OUTPUT_DIR/vibestack-termius.csv"
fi

if [ -n "$COOLIFY_IP" ] && [ "$COOLIFY_IP" != "null" ]; then
    echo "Coolify-server-$COMPARTMENT_NAME,\"vibestack oci coolify $COMPARTMENT_NAME\",$COOLIFY_IP,$SSH_USERNAME,$SSH_PORT,\"Coolify app platform server - VibeStack deployment (2 OCPUs, 12GB RAM, 100GB storage) - Private IP: $COOLIFY_PRIVATE_IP\"" >> "$OUTPUT_DIR/vibestack-termius.csv"
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

# Generate JSON file (manually constructed)
echo -e "${YELLOW}Generating JSON import file...${NC}"
cat > "$OUTPUT_DIR/vibestack-termius.json" << 'JSON_START'
{
  "hosts": [
JSON_START

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

cat >> "$OUTPUT_DIR/vibestack-termius.json" << 'JSON_END'

  ]
}
JSON_END

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

# Cleanup temp file
rm -f "/tmp/terraform_output.json"

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