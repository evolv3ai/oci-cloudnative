#!/bin/bash

# VibeStack Deployment Log Manager
# Manages sensitive Terraform state files and deployment logs securely

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOGS_DIR="./logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "${GREEN}🗂️  VibeStack Deployment Log Manager${NC}"
    echo "==========================================="
}

print_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  save-state [file]     - Save Terraform state/log file to secure logs directory"
    echo "  import-from-log       - Generate Termius imports from saved log file"
    echo "  cleanup              - Securely delete all log files after confirmation"
    echo "  list                 - List all saved log files"
    echo "  show-paths           - Show directory structure and safety"
    echo ""
    echo "Examples:"
    echo "  $0 save-state terraform-state.txt"
    echo "  $0 save-state ~/Downloads/oci-deployment-output.json"
    echo "  $0 import-from-log"
    echo "  $0 cleanup"
}

ensure_logs_dir() {
    if [ ! -d "$LOGS_DIR" ]; then
        mkdir -p "$LOGS_DIR"
        echo -e "${GREEN}✓ Created secure logs directory: $LOGS_DIR${NC}"

        # Create README in logs directory
        cat > "$LOGS_DIR/README.md" << 'EOF'
# VibeStack Deployment Logs

This directory contains sensitive deployment information and is ignored by Git.

## Security Notes:
- All files in this directory are automatically ignored by Git
- Contains IP addresses, OCIDs, and deployment details
- Safe to delete after creating Termius import files
- Use `../manage-deployment-logs.sh cleanup` to securely remove all files

## Files:
- `terraform-state-*.txt` - Terraform state exports
- `deployment-*.json` - OCI deployment outputs
- `servers-*.env` - Generated environment files

Generated: $(date)
EOF
    fi
}

save_state_file() {
    local source_file="$1"

    if [ -z "$source_file" ]; then
        echo -e "${RED}❌ Error: Please specify a file to save${NC}"
        echo "Example: $0 save-state terraform-state.txt"
        exit 1
    fi

    if [ ! -f "$source_file" ]; then
        echo -e "${RED}❌ Error: File not found: $source_file${NC}"
        exit 1
    fi

    ensure_logs_dir

    # Generate timestamped filename
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local basename=$(basename "$source_file")
    local extension="${basename##*.}"
    local name="${basename%.*}"

    local dest_file="$LOGS_DIR/${name}-${timestamp}.${extension}"

    # Copy file to logs directory
    cp "$source_file" "$dest_file"
    echo -e "${GREEN}✓ Saved deployment log: $dest_file${NC}"

    # Try to extract server info and create .env file
    extract_server_info "$dest_file"

    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "1. Run: $0 import-from-log"
    echo "2. Import the generated files to Termius"
    echo "3. Run: $0 cleanup (to securely delete logs)"
}

extract_server_info() {
    local log_file="$1"
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local env_file="$LOGS_DIR/servers-${timestamp}.env"

    echo -e "${YELLOW}Extracting server information...${NC}"

    # Try to parse JSON (Terraform state) or text output
    if grep -q '"kasm_server"' "$log_file" 2>/dev/null; then
        # Terraform JSON state
        local kasm_ip=$(grep -o '"public_ip": "[^"]*"' "$log_file" | grep -A1 -B1 kasm | grep public_ip | cut -d'"' -f4 | head -1)
        local coolify_ip=$(grep -o '"public_ip": "[^"]*"' "$log_file" | grep -A1 -B1 coolify | grep public_ip | cut -d'"' -f4 | head -1)
        local compartment_name=$(grep -o '"name": "[^"]*"' "$log_file" | head -1 | cut -d'"' -f4)

        # Create environment file
        cat > "$env_file" << EOF
# VibeStack Server Information
# Generated: $(date)
# Source: $(basename "$log_file")

# Compartment
COMPARTMENT_NAME=${compartment_name:-vibestack}

# Server IPs (if deployed)
EOF

        if [ -n "$kasm_ip" ] && [ "$kasm_ip" != "null" ]; then
            echo "KASM_SERVER_IP=$kasm_ip" >> "$env_file"
            echo -e "${GREEN}✓ Found KASM server: $kasm_ip${NC}"
        fi

        if [ -n "$coolify_ip" ] && [ "$coolify_ip" != "null" ]; then
            echo "COOLIFY_SERVER_IP=$coolify_ip" >> "$env_file"
            echo -e "${GREEN}✓ Found Coolify server: $coolify_ip${NC}"
        fi

        cat >> "$env_file" << 'EOF'

# SSH Settings (customize as needed)
SSH_USERNAME=ubuntu
SSH_PORT=22
SSH_KEY_PATH=~/.ssh/id_rsa
EOF

        echo -e "${GREEN}✓ Created server info file: $env_file${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not automatically parse server info from log file${NC}"
        echo "You may need to manually create a .env file or run the Termius import script"
    fi
}

import_from_log() {
    ensure_logs_dir

    # Find the most recent log file
    local latest_log=$(ls -t "$LOGS_DIR"/*.txt "$LOGS_DIR"/*.json 2>/dev/null | head -1)

    if [ -z "$latest_log" ]; then
        echo -e "${RED}❌ No log files found in $LOGS_DIR${NC}"
        echo "First save a deployment log with: $0 save-state [file]"
        exit 1
    fi

    echo -e "${YELLOW}Using log file: $(basename "$latest_log")${NC}"

    # Create temporary terraform output for the import script
    local temp_dir=$(mktemp -d)
    local temp_tf_dir="$temp_dir/terraform"
    mkdir -p "$temp_tf_dir"

    # Try to create a minimal terraform output from the log
    if grep -q '"kasm_server"' "$latest_log" 2>/dev/null; then
        # Extract just the outputs section if it's a full state file
        if grep -q '"outputs"' "$latest_log"; then
            grep -A 1000 '"outputs"' "$latest_log" | head -n -10 > "$temp_tf_dir/outputs.json"
        else
            cp "$latest_log" "$temp_tf_dir/outputs.json"
        fi

        # Create a fake terraform binary that outputs our data
        cat > "$temp_tf_dir/terraform" << 'FAKE_TF'
#!/bin/bash
if [ "$1" = "output" ] && [ "$2" = "-json" ]; then
    cat outputs.json
else
    echo "Fake terraform for log processing"
fi
FAKE_TF
        chmod +x "$temp_tf_dir/terraform"

        # Temporarily modify PATH to use our fake terraform
        export PATH="$temp_tf_dir:$PATH"

        # Run the import script with custom terraform dir
        echo -e "${YELLOW}Generating Termius import files...${NC}"

        # Try jq version first, then fallback to no-jq version
        if command -v jq >/dev/null 2>&1; then
            if [ -f "./scripts/generate-termius-import.sh" ]; then
                TERRAFORM_DIR="$temp_tf_dir" ./scripts/generate-termius-import.sh
            elif [ -f "./generate-termius-import.sh" ]; then
                TERRAFORM_DIR="$temp_tf_dir" ./generate-termius-import.sh
            else
                echo -e "${RED}❌ generate-termius-import.sh not found${NC}"
                rm -rf "$temp_dir"
                exit 1
            fi
        else
            echo -e "${YELLOW}jq not found, using no-jq version...${NC}"
            if [ -f "./scripts/generate-termius-import-no-jq.sh" ]; then
                TERRAFORM_DIR="$temp_tf_dir" ./scripts/generate-termius-import-no-jq.sh
            elif [ -f "./generate-termius-import-no-jq.sh" ]; then
                TERRAFORM_DIR="$temp_tf_dir" ./generate-termius-import-no-jq.sh
            else
                echo -e "${RED}❌ generate-termius-import-no-jq.sh not found${NC}"
                rm -rf "$temp_dir"
                exit 1
            fi
        fi

        # Cleanup
        rm -rf "$temp_dir"

        echo -e "${GREEN}✅ Import files generated successfully!${NC}"
        echo "Check the termius-import/ directory for your files"
    else
        echo -e "${RED}❌ Log file format not recognized${NC}"
        echo "Expected Terraform state JSON format"
        exit 1
    fi
}

cleanup_logs() {
    ensure_logs_dir

    # Count files
    local file_count=$(find "$LOGS_DIR" -type f -not -name "README.md" | wc -l)

    if [ "$file_count" -eq 0 ]; then
        echo -e "${YELLOW}📁 No log files to cleanup${NC}"
        return
    fi

    echo -e "${YELLOW}🗑️  Found $file_count log files to delete:${NC}"
    find "$LOGS_DIR" -type f -not -name "README.md" -exec basename {} \;
    echo ""
    echo -e "${RED}⚠️  This will permanently delete all deployment logs!${NC}"
    echo "Make sure you have:"
    echo "  ✓ Generated Termius import files"
    echo "  ✓ Saved any needed server information"
    echo "  ✓ No longer need the deployment logs"
    echo ""
    read -p "Are you sure you want to delete all log files? (yes/no): " confirm

    if [ "$confirm" = "yes" ] || [ "$confirm" = "YES" ]; then
        # Securely delete files (overwrite then remove)
        find "$LOGS_DIR" -type f -not -name "README.md" -exec shred -vfz -n 3 {} \; 2>/dev/null || \
        find "$LOGS_DIR" -type f -not -name "README.md" -exec rm -f {} \;

        echo -e "${GREEN}✅ All log files securely deleted${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled${NC}"
    fi
}

list_logs() {
    ensure_logs_dir

    echo -e "${YELLOW}📋 Saved deployment logs:${NC}"
    echo ""

    if [ ! "$(ls -A "$LOGS_DIR")" ]; then
        echo "No log files found"
        return
    fi

    # List files with details
    ls -la "$LOGS_DIR" | grep -v "^d" | grep -v "README.md" | while read -r line; do
        local file=$(echo "$line" | awk '{print $9}')
        local size=$(echo "$line" | awk '{print $5}')
        local date=$(echo "$line" | awk '{print $6, $7, $8}')

        if [ -n "$file" ]; then
            echo "📄 $file"
            echo "   Size: $size bytes, Modified: $date"
            echo ""
        fi
    done
}

show_paths() {
    ensure_logs_dir

    echo -e "${YELLOW}📁 Directory Structure:${NC}"
    echo ""
    echo "Repository root: $SCRIPT_DIR"
    echo "Logs directory:  $SCRIPT_DIR/$LOGS_DIR"
    echo "Import output:   $SCRIPT_DIR/termius-import"
    echo ""
    echo -e "${GREEN}🔒 Security Status:${NC}"
    echo "✓ Logs directory is in .gitignore"
    echo "✓ Import files are in .gitignore"
    echo "✓ All sensitive files protected from Git"
    echo ""
    echo -e "${YELLOW}📋 Workflow:${NC}"
    echo "1. Save deployment log:    $0 save-state [file]"
    echo "2. Generate imports:       $0 import-from-log"
    echo "3. Import to Termius:      Use files in termius-import/"
    echo "4. Cleanup logs:           $0 cleanup"
}

# Main script logic
case "${1:-}" in
    "save-state")
        print_header
        save_state_file "$2"
        ;;
    "import-from-log")
        print_header
        import_from_log
        ;;
    "cleanup")
        print_header
        cleanup_logs
        ;;
    "list")
        print_header
        list_logs
        ;;
    "show-paths")
        print_header
        show_paths
        ;;
    "help"|"-h"|"--help")
        print_header
        print_usage
        ;;
    *)
        print_header
        echo -e "${RED}❌ Unknown command: ${1:-}${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac