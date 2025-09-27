#!/bin/bash
# SSL Certificate Verification Script for VibeStack Coolify
# Run this to verify your certificates before deployment

echo "==================================================="
echo "VibeStack SSL Certificate Verification Tool"
echo "==================================================="

# Function to check if a file contains valid PEM certificate
check_certificate() {
    local file="$1"
    local type="$2"
    
    echo ""
    echo "Checking $type: $file"
    echo "-------------------------------------------------"
    
    if [ ! -f "$file" ]; then
        echo "❌ ERROR: File not found!"
        return 1
    fi
    
    # Check for Windows line endings
    if file "$file" | grep -q "CRLF"; then
        echo "⚠️ WARNING: File contains Windows line endings (CRLF)"
        echo "  Fix with: dos2unix $file or sed -i 's/\r$//' $file"
    fi
    
    # Check PEM structure
    if ! grep -q "BEGIN" "$file"; then
        echo "❌ ERROR: No PEM header found!"
        return 1
    fi
    
    if ! grep -q "END" "$file"; then
        echo "❌ ERROR: No PEM footer found!"
        return 1
    fi
    
    # Validate based on type
    case "$type" in
        "Certificate")
            if openssl x509 -in "$file" -noout -text > /dev/null 2>&1; then
                echo "✅ Valid X.509 certificate"
                
                # Extract and display certificate details
                echo "  Subject: $(openssl x509 -in "$file" -noout -subject | cut -d= -f2-)"
                echo "  Issuer: $(openssl x509 -in "$file" -noout -issuer | cut -d= -f2-)"
                echo "  Valid from: $(openssl x509 -in "$file" -noout -startdate | cut -d= -f2)"
                echo "  Valid until: $(openssl x509 -in "$file" -noout -enddate | cut -d= -f2)"
                
                # Extract SANs for domain verification
                echo "  Domains (SANs):"
                openssl x509 -in "$file" -noout -text | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g' | tr ',' '\n' | sed 's/^/    - /'
            else
                echo "❌ ERROR: Invalid certificate format!"
                echo "  OpenSSL error:"
                openssl x509 -in "$file" -noout -text 2>&1 | grep -i error
                return 1
            fi
            ;;
            
        "Private Key")
            # Try RSA key first
            if openssl rsa -in "$file" -check -noout > /dev/null 2>&1; then
                echo "✅ Valid RSA private key"
                echo "  Key size: $(openssl rsa -in "$file" -text -noout 2>/dev/null | grep "Private-Key:" | cut -d: -f2)"
            # Try generic private key
            elif openssl pkey -in "$file" -noout > /dev/null 2>&1; then
                echo "✅ Valid private key (non-RSA)"
            else
                echo "❌ ERROR: Invalid private key format!"
                echo "  OpenSSL error:"
                openssl rsa -in "$file" -check -noout 2>&1 | grep -i error
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to check if certificate and key match
check_cert_key_match() {
    local cert="$1"
    local key="$2"
    
    echo ""
    echo "Checking certificate/key pair match..."
    echo "-------------------------------------------------"
    
    if [ ! -f "$cert" ] || [ ! -f "$key" ]; then
        echo "❌ Cannot check match - files missing"
        return 1
    fi
    
    # Get modulus from certificate
    cert_modulus=$(openssl x509 -in "$cert" -noout -modulus 2>/dev/null | openssl md5)
    # Get modulus from private key
    key_modulus=$(openssl rsa -in "$key" -noout -modulus 2>/dev/null | openssl md5)
    
    if [ -z "$cert_modulus" ] || [ -z "$key_modulus" ]; then
        # Try with pkey for non-RSA keys
        key_modulus=$(openssl pkey -in "$key" -pubout 2>/dev/null | openssl md5)
    fi
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        echo "✅ Certificate and private key match!"
    else
        echo "❌ ERROR: Certificate and private key DO NOT match!"
        echo "  This will cause SSL to fail!"
        return 1
    fi
}

# Function to simulate base64 encoding/decoding process
test_base64_roundtrip() {
    local file="$1"
    local type="$2"
    
    echo ""
    echo "Testing base64 encode/decode for $type..."
    echo "-------------------------------------------------"
    
    # Encode
    base64 "$file" > "/tmp/test.b64"
    
    # Decode
    base64 -d "/tmp/test.b64" > "/tmp/test.decoded"
    
    # Compare
    if diff -q "$file" "/tmp/test.decoded" > /dev/null; then
        echo "✅ Base64 roundtrip successful"
    else
        echo "❌ ERROR: Base64 roundtrip failed!"
        echo "  File was corrupted during encode/decode"
        return 1
    fi
    
    # Clean up
    rm -f /tmp/test.b64 /tmp/test.decoded
}

# Main script
main() {
    echo ""
    echo "Usage: $0 <certificate.pem> <private-key.pem>"
    echo ""
    
    if [ $# -lt 2 ]; then
        echo "Please provide both certificate and private key files"
        exit 1
    fi
    
    CERT_FILE="$1"
    KEY_FILE="$2"
    
    # Run all checks
    ERRORS=0
    
    check_certificate "$CERT_FILE" "Certificate" || ((ERRORS++))
    check_certificate "$KEY_FILE" "Private Key" || ((ERRORS++))
    check_cert_key_match "$CERT_FILE" "$KEY_FILE" || ((ERRORS++))
    test_base64_roundtrip "$CERT_FILE" "Certificate" || ((ERRORS++))
    test_base64_roundtrip "$KEY_FILE" "Private Key" || ((ERRORS++))
    
    # Final summary
    echo ""
    echo "==================================================="
    echo "VERIFICATION SUMMARY"
    echo "==================================================="
    
    if [ $ERRORS -eq 0 ]; then
        echo "✅ ALL CHECKS PASSED!"
        echo ""
        echo "Your certificates are ready for deployment."
        echo "They should work correctly with the Coolify setup."
    else
        echo "❌ FAILED: $ERRORS check(s) failed"
        echo ""
        echo "Please fix the issues above before deployment."
        echo ""
        echo "Common fixes:"
        echo "1. Remove Windows line endings: dos2unix <file>"
        echo "2. Ensure PEM format has proper headers/footers"
        echo "3. Verify certificate and key are from same generation"
        echo "4. Check that private key is not encrypted"
    fi
}

# Run main function
main "$@"
