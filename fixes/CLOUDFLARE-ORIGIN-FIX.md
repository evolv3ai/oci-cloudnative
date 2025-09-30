# CRITICAL FIX for Cloudflare Origin Certificates
# Problem: Certificates from Cloudflare UI are already in PEM format
# Current code base64-encodes them TWICE, breaking everything

## The Issue Chain:
1. User pastes PEM certificate (already perfect format)
2. locals.tf base64-encodes it (unnecessary)
3. cloud-init writes the base64 
4. cloud-init tries to decode and "fix" format (breaks it)
5. Ansible gets corrupted certificates

## THE SIMPLEST FIX - Replace just the SSL processing in cloud-init

In `cloud-init-coolify.yaml`, replace the entire SSL processing section (lines ~180-195) with:

```yaml
%{ if setup_custom_ssl ~}
  # Process SSL certificates - SIMPLIFIED VERSION FOR PEM INPUT
  - |
    echo "Processing SSL certificates..." >> /var/log/vibestack-setup.log
    
    # Just decode the base64 - the content is already perfect PEM
    if [ -f /opt/vibestack/ssl.cert.b64 ]; then
      base64 -d /opt/vibestack/ssl.cert.b64 > /opt/vibestack/ssl.cert
      echo "Certificate decoded" >> /var/log/vibestack-setup.log
    fi
    
    if [ -f /opt/vibestack/ssl.key.b64 ]; then
      base64 -d /opt/vibestack/ssl.key.b64 > /opt/vibestack/ssl.key
      echo "Private key decoded" >> /var/log/vibestack-setup.log
    fi
    
    # Set permissions
    chmod 644 /opt/vibestack/ssl.cert
    chmod 600 /opt/vibestack/ssl.key
    
    # Validate the files
    if openssl x509 -in /opt/vibestack/ssl.cert -noout; then
      echo "Certificate is valid" >> /var/log/vibestack-setup.log
    else
      echo "ERROR: Certificate validation failed!" >> /var/log/vibestack-setup.log
    fi
    
    if openssl rsa -in /opt/vibestack/ssl.key -check -noout 2>/dev/null || \
       openssl pkey -in /opt/vibestack/ssl.key -noout 2>/dev/null; then
      echo "Private key is valid" >> /var/log/vibestack-setup.log
    else
      echo "ERROR: Private key validation failed!" >> /var/log/vibestack-setup.log
    fi
    
    # Clean up
    rm -f /opt/vibestack/*.b64
%{ endif ~}
```

That's it! This removes ALL the format manipulation that was breaking your certificates.

## Why Your Current Setup Fails:

Your log shows "SSL certificates processed successfully" but Ansible fails because:
1. The certificates ARE processed (files created)
2. But they're CORRUPTED by the format "fixing"
3. Ansible can't use invalid certificates

## Testing Before Deployment:

Save this as `test-cert-encoding.sh`:

```bash
#!/bin/bash
# Test what happens to your certificate

# Paste your cert here (or read from file)
CERT="-----BEGIN CERTIFICATE-----
MIIEpjCCA46gAwIBAgIURkoyWiwqDqH+I5C52qoWB1QXaP0wDQYJKoZIhvcNAQEL
... (your full cert) ...
-----END CERTIFICATE-----"

# What locals.tf does
echo "$CERT" | base64 > cert.b64

# What cloud-init SHOULD do (simple decode)
base64 -d cert.b64 > cert.good

# What cloud-init CURRENTLY does (breaks it)
base64 -d cert.b64 | fold -w 64 > /tmp/temp.crt
{
  echo "-----BEGIN CERTIFICATE-----"
  grep -v "BEGIN CERTIFICATE\|END CERTIFICATE" /tmp/temp.crt | tr -d '\n' | fold -w 64
  echo "-----END CERTIFICATE-----"
} > cert.bad

# Compare
echo "=== Original vs Good (should be identical) ==="
diff <(echo "$CERT") cert.good

echo "=== Original vs Bad (will show corruption) ==="
diff <(echo "$CERT") cert.bad

# Validate
echo "=== Validation ==="
openssl x509 -in cert.good -noout && echo "cert.good: VALID" || echo "cert.good: INVALID"
openssl x509 -in cert.bad -noout && echo "cert.bad: VALID" || echo "cert.bad: INVALID"
```

## Alternative: Direct PEM Input (No Encoding)

If you want to eliminate base64 entirely, in `locals.tf`:

```hcl
# Don't encode - pass PEM directly
ssl_cert_b64 = local.setup_custom_ssl ? var.origin_certificate : ""
ssl_key_b64 = local.setup_custom_ssl ? var.private_key : ""
```

And in cloud-init, write directly without base64:

```yaml
- content: |
      ${ssl_cert_b64}
  path: /opt/vibestack/ssl.cert
  permissions: '0644'
  encoding: plain

- content: |
      ${ssl_key_b64}
  path: /opt/vibestack/ssl.key
  permissions: '0600'
  encoding: plain
```

This is even simpler but requires testing how OCI handles multi-line variables.
