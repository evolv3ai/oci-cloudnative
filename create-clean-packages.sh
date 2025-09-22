#!/bin/bash

# Script to create clean VibeStack packages

echo "Creating clean VibeStack repository structure..."

# Base directory
CLEAN_DIR="clean-vibestack"
rm -rf $CLEAN_DIR
mkdir -p $CLEAN_DIR/{terraform/{vibestack,coolify-only,kasm-only},docs,.github/workflows}

echo "1. Creating VibeStack (both servers) package..."
cp deploy/basic/terraform/*.tf $CLEAN_DIR/terraform/vibestack/
cp deploy/basic/terraform/schema.yaml $CLEAN_DIR/terraform/vibestack/

echo "2. Creating Coolify-only package..."
cp deploy/basic/terraform/*.tf $CLEAN_DIR/terraform/coolify-only/

# Remove KASM resources from Coolify-only
sed -i '/^resource "oci_core_instance" "kasm"/,/^}/d' $CLEAN_DIR/terraform/coolify-only/compute.tf

# Remove KASM variables
sed -i '/^variable "kasm_/,/^}/d' $CLEAN_DIR/terraform/coolify-only/variables.tf

# Remove KASM storage
sed -i '/^resource "oci_core_volume" "kasm_data"/,/^}/d' $CLEAN_DIR/terraform/coolify-only/storage.tf
sed -i '/^resource "oci_core_volume_attachment" "kasm"/,/^}/d' $CLEAN_DIR/terraform/coolify-only/storage.tf

# Remove KASM outputs
sed -i '/^output "kasm_server"/,/^}/d' $CLEAN_DIR/terraform/coolify-only/outputs.tf

# Remove KASM locals
sed -i '/kasm_/d' $CLEAN_DIR/terraform/coolify-only/locals.tf

echo "3. Creating KASM-only package..."
cp deploy/basic/terraform/*.tf $CLEAN_DIR/terraform/kasm-only/

# Remove Coolify resources from KASM-only
sed -i '/^resource "oci_core_instance" "coolify"/,/^}/d' $CLEAN_DIR/terraform/kasm-only/compute.tf

# Remove Coolify variables
sed -i '/^variable "coolify_/,/^}/d' $CLEAN_DIR/terraform/kasm-only/variables.tf

# Remove Coolify storage
sed -i '/^resource "oci_core_volume" "coolify_data"/,/^}/d' $CLEAN_DIR/terraform/kasm-only/storage.tf
sed -i '/^resource "oci_core_volume_attachment" "coolify"/,/^}/d' $CLEAN_DIR/terraform/kasm-only/storage.tf

# Remove Coolify outputs
sed -i '/^output "coolify_server"/,/^}/d' $CLEAN_DIR/terraform/kasm-only/outputs.tf

# Remove Coolify locals
sed -i '/coolify_/d' $CLEAN_DIR/terraform/kasm-only/locals.tf

echo "4. Creating documentation..."
cp docs/oci-vibestack-recommended-setup.md $CLEAN_DIR/docs/
cp docs/deploy-button-specification.md $CLEAN_DIR/docs/

echo "5. Creating essential files..."
cp CLAUDE.md $CLEAN_DIR/
cp LICENSE.txt $CLEAN_DIR/LICENSE
cp .github/workflows/release-vibestack.yml $CLEAN_DIR/.github/workflows/

echo "✅ Clean VibeStack repository created in: $CLEAN_DIR"
echo "📊 Size comparison:"
echo "Original: $(du -sh . | cut -f1)"
echo "Clean:    $(du -sh $CLEAN_DIR | cut -f1)"

ls -la $CLEAN_DIR/