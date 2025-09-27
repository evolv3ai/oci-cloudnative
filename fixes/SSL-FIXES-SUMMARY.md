# Coolify SSL Certificate Issue Analysis & Fixes

## Critical Issues Identified

### 1. Double Base64 Encoding Problem
**Issue**: Certificates are being base64-encoded twice:
- First in `locals.tf` when passed to cloud-init
- Again written as base64 in cloud-init yaml
- Decoding process corrupts the PEM format

**Fix**: Only encode once in `locals.tf`, then decode properly in cloud-init

### 2. PEM Format Corruption During Processing
**Issue**: The cloud-init script mangles certificates by:
- Stripping PEM headers/footers
- Removing ALL line breaks 
- Incorrectly re-folding to 64 chars
- Re-adding headers incorrectly

**Fix**: Simply decode base64 and write directly - PEM format is already correct

### 3. Private Key Not Being Written
**Issue**: The `.key` file path and decoding are broken:
- Script looks for `ssl-key.b64` but file is `ssl.key.b64`
- Decoding fails silently
- No error checking on key validation

**Fix**: Correct file paths and add validation

### 4. Certificate Validation Missing
**Issue**: No verification that certificates are valid before use
**Fix**: Add OpenSSL validation checks

## Recommended Implementation Steps

### Step 1: Apply Fixed Cloud-Init
Replace `cloud-init-coolify.yaml` with the fixed version that:
- Properly decodes base64 only once
- Preserves PEM format exactly
- Validates certificates with OpenSSL
- Logs all operations for debugging

### Step 2: Update locals.tf
Use the fixed `locals.tf` that:
- Only base64-encodes once
- Preserves exact PEM format
- Cleans input but doesn't modify structure

### Step 3: Test Certificates Before Deployment
Use the verification script to check certificates locally:
```bash
bash verify-ssl-certs.sh cert.pem key.pem
```

### Step 4: Debug Deployment
After deployment, SSH to instance and check:
```bash
# Check if files exist
ls -la /opt/vibestack-ansible/ssl*

# Verify certificate
openssl x509 -in /opt/vibestack-ansible/ssl.cert -noout -text

# Verify private key
openssl rsa -in /opt/vibestack-ansible/ssl.key -check -noout

# Check logs
cat /var/log/vibestack-setup.log | grep -i ssl
```

## Schema.yaml Form Field Issues

The current form uses:
- `type: text` for certificate (visible)
- `type: password` for private key (hidden)

**Recommendation**: Change both to `type: text` with proper multiline support:
```yaml
origin_certificate:
  type: text
  title: "Origin Certificate"
  description: "Paste your certificate in PEM format (including headers)"
  multiline: true
  rows: 10

private_key:
  type: text  # Change from password to text
  title: "Private Key"
  description: "Paste your private key in PEM format (including headers)"
  multiline: true
  rows: 10
  sensitive: true  # Still mark as sensitive
```

## Testing Checklist

1. [ ] Verify certificates locally with script
2. [ ] Deploy with fixed cloud-init
3. [ ] SSH to instance after deployment
4. [ ] Check `/var/log/vibestack-setup.log` for SSL entries
5. [ ] Verify files in `/opt/vibestack-ansible/`
6. [ ] Check Coolify container for certificate mounting
7. [ ] Test HTTPS access to Coolify UI

## Quick Debug Commands

```bash
# On deployed instance
sudo -i
cd /opt/vibestack-ansible

# Check what was written
ls -la ssl*
file ssl.cert ssl.key

# Validate formats
openssl x509 -in ssl.cert -noout -text
openssl rsa -in ssl.key -check -noout

# Check if Coolify picked them up
docker exec coolify ls -la /data/coolify/proxy/certs/

# View setup logs
grep -i ssl /var/log/vibestack-setup.log
```

## Next Steps

1. **Immediate**: Apply the fixed cloud-init and locals.tf
2. **Test**: Deploy a test instance with known-good certificates
3. **Validate**: Use debug commands to verify proper installation
4. **Consider**: Adding Cloudflare tunnel as primary method (auto-SSL)
5. **Document**: Update README with certificate format requirements
