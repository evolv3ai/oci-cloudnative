#!/bin/bash

# Simple test to extract values from the log file
LOG_FILE="logs/vibestack-terraform-state-20250922-085438.txt"

echo "Testing simple extraction from: $LOG_FILE"
echo "============================================"

# Extract KASM IP
KASM_IP=$(grep -A 20 '"kasm_server"' "$LOG_FILE" | grep '"public_ip"' | head -1 | sed 's/.*"public_ip":[[:space:]]*"//' | sed 's/".*//')
echo "KASM IP: [$KASM_IP]"

# Extract Coolify IP
COOLIFY_IP=$(grep -A 20 '"coolify_server"' "$LOG_FILE" | grep '"public_ip"' | head -1 | sed 's/.*"public_ip":[[:space:]]*"//' | sed 's/".*//')
echo "Coolify IP: [$COOLIFY_IP]"

# Extract compartment name
COMPARTMENT_NAME=$(grep -A 10 '"compartment"' "$LOG_FILE" | grep '"name"' | head -1 | sed 's/.*"name":[[:space:]]*"//' | sed 's/".*//')
echo "Compartment: [$COMPARTMENT_NAME]"

# Extract private IPs
KASM_PRIVATE_IP=$(grep -A 20 '"kasm_server"' "$LOG_FILE" | grep '"private_ip"' | head -1 | sed 's/.*"private_ip":[[:space:]]*"//' | sed 's/".*//')
echo "KASM Private IP: [$KASM_PRIVATE_IP]"

COOLIFY_PRIVATE_IP=$(grep -A 20 '"coolify_server"' "$LOG_FILE" | grep '"private_ip"' | head -1 | sed 's/.*"private_ip":[[:space:]]*"//' | sed 's/".*//')
echo "Coolify Private IP: [$COOLIFY_PRIVATE_IP]"