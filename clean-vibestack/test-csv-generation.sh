#!/bin/bash

# Quick test to generate the updated CSV format
LOG_FILE="logs/vibestack-terraform-state-20250922-085438.txt"
OUTPUT_DIR="./termius-import"

echo "Testing updated CSV generation..."

# Extract values
KASM_IP=$(grep -A 20 '"kasm_server"' "$LOG_FILE" | grep '"public_ip"' | head -1 | sed 's/.*"public_ip":[[:space:]]*"//' | sed 's/".*//')
COOLIFY_IP=$(grep -A 20 '"coolify_server"' "$LOG_FILE" | grep '"public_ip"' | head -1 | sed 's/.*"public_ip":[[:space:]]*"//' | sed 's/".*//')
COMPARTMENT_NAME=$(grep -A 10 '"compartment"' "$LOG_FILE" | grep '"name"' | head -1 | sed 's/.*"name":[[:space:]]*"//' | sed 's/".*//')

echo "Found: KASM=$KASM_IP, Coolify=$COOLIFY_IP, Compartment=$COMPARTMENT_NAME"

# Generate CSV in Termius format
cat > "$OUTPUT_DIR/vibestack-termius.csv" << EOF
Groups,Label,Tags,Hostname/IP,Protocol,Port
EOF

if [ -n "$KASM_IP" ]; then
    echo "VibeStack OCI - $COMPARTMENT_NAME,KASM-server-$COMPARTMENT_NAME,\"vibestack oci kasm $COMPARTMENT_NAME\",$KASM_IP,ssh,22" >> "$OUTPUT_DIR/vibestack-termius.csv"
fi

if [ -n "$COOLIFY_IP" ]; then
    echo "VibeStack OCI - $COMPARTMENT_NAME,Coolify-server-$COMPARTMENT_NAME,\"vibestack oci coolify $COMPARTMENT_NAME\",$COOLIFY_IP,ssh,22" >> "$OUTPUT_DIR/vibestack-termius.csv"
fi

echo "Generated CSV:"
cat "$OUTPUT_DIR/vibestack-termius.csv"