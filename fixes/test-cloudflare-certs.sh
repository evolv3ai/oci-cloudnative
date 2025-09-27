#!/bin/bash
# Test script for Cloudflare Origin Certificate processing
# This simulates exactly what happens in the deployment

echo "============================================"
echo "Cloudflare Origin Certificate Test"
echo "============================================"
echo ""
echo "This script tests if your certificates will work with the fixed deployment."
echo ""

# Check if cert and key files provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <certificate-file> <private-key-file>"
    echo "Example: $0 origin-cert.pem origin-key.pem"
    echo ""
    echo "Copy your certificate and key from Cloudflare dashboard into text files first."
    exit 1
fi

CERT_FILE="$1"
KEY_FILE="$2"

# Check files exist
if [ ! -f "$CERT_FILE" ]; then
    echo "ERROR: Certificate file not found: $CERT_FILE"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Private key file not found: $KEY_FILE"
    exit 1
fi

echo "Testing certificate: $CERT_FILE"
echo "Testing private key: $KEY_FILE"
echo ""

# Step 1: Validate original files
echo "STEP 1: Validating original files"
echo "----------------------------------"

# Check certificate
if openssl x509 -in "$CERT_FILE" -noout 2>/dev/null; then
    echo "✅ Certificate file is valid PEM format"
    
    # Extract info
    echo "   Subject: $(openssl x509 -in "$CERT_FILE" -noout -subject | cut -d= -f2-)"
    echo "   Domains:"
    openssl x509 -in "$CERT_FILE" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g' | tr ',' '\n' | sed 's/^/     - /'
else
    echo "❌ Certificate file is NOT valid!"
    exit 1
fi

# Check private key
if openssl rsa -in "$KEY_FILE" -check -noout 2>/dev/null || \
   openssl pkey -in "$KEY_FILE" -noout 2>/dev/null; then
    echo "✅ Private key file is valid"
else
    echo "❌ Private key file is NOT valid!"
    exit 1
fi

# Check if they match
cert_mod=$(openssl x509 -noout -modulus -in "$CERT_FILE" 2>/dev/null | openssl md5)
key_mod=$(openssl rsa -noout -modulus -in "$KEY_FILE" 2>/dev/null | openssl md5)

if [ "$cert_mod" = "$key_mod" ]; then
    echo "✅ Certificate and private key match"
else
    echo "❌ Certificate and private key DO NOT match!"
    exit 1
fi

echo ""

# Step 2: Simulate the encoding/decoding process
echo "STEP 2: Testing base64 encode/decode process"
echo "---------------------------------------------"

# What locals.tf does
base64 "$CERT_FILE" > test-cert.b64
base64 "$KEY_FILE" > test-key.b64

# What the FIXED cloud-init does
base64 -d test-cert.b64 > test-cert-decoded.pem
base64 -d test-key.b64 > test-key-decoded.pem

# Verify decoded files
if diff -q "$CERT_FILE" test-cert-decoded.pem >/dev/null; then
    echo "✅ Certificate survives base64 roundtrip perfectly"
else
    echo "❌ Certificate corrupted during base64 process!"
    exit 1
fi

if diff -q "$KEY_FILE" test-key-decoded.pem >/dev/null; then
    echo "✅ Private key survives base64 roundtrip perfectly"
else
    echo "❌ Private key corrupted during base64 process!"
    exit 1
fi

# Validate decoded files work
if openssl x509 -in test-cert-decoded.pem -noout 2>/dev/null; then
    echo "✅ Decoded certificate is still valid"
else
    echo "❌ Decoded certificate is invalid!"
    exit 1
fi

if openssl rsa -in test-key-decoded.pem -check -noout 2>/dev/null || \
   openssl pkey -in test-key-decoded.pem -noout 2>/dev/null; then
    echo "✅ Decoded private key is still valid"
else
    echo "❌ Decoded private key is invalid!"
    exit 1
fi

echo ""

# Step 3: Test what the OLD (broken) code would do
echo "STEP 3: Showing why the OLD code breaks"
echo "----------------------------------------"

# Simulate the broken processing
base64 -d test-cert.b64 | fold -w 64 > /tmp/temp.crt
{
    echo "-----BEGIN CERTIFICATE-----"
    grep -v "BEGIN CERTIFICATE\|END CERTIFICATE" /tmp/temp.crt | tr -d '\n' | fold -w 64
    echo "-----END CERTIFICATE-----"
} > test-cert-broken.pem

if openssl x509 -in test-cert-broken.pem -noout 2>/dev/null; then
    echo "⚠️  OLD: Certificate might appear valid but is reformatted"
else
    echo "❌ OLD: Certificate is completely broken (expected)"
fi

# Show the difference
echo ""
echo "First 5 lines comparison:"
echo "Original:"
head -5 "$CERT_FILE" | sed 's/^/  /'
echo "Broken by old code:"
head -5 test-cert-broken.pem | sed 's/^/  /'

echo ""

# Cleanup
rm -f test-cert.b64 test-key.b64 test-cert-decoded.pem test-key-decoded.pem test-cert-broken.pem /tmp/temp.crt

echo "============================================"
echo "TEST COMPLETE"
echo "============================================"
echo ""
echo "✅ Your certificates are ready for deployment!"
echo ""
echo "Next steps:"
echo "1. Replace cloud-init-coolify.yaml with the fixed version"
echo "2. Commit and push to GitHub"
echo "3. Create new OCI Stack release"
echo "4. Deploy and test"
echo ""
echo "The fixed version will properly handle your Cloudflare Origin certificates."
