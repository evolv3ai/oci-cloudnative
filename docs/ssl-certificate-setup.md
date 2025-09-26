# SSL Certificate Setup for Coolify

This guide explains how to configure SSL certificates for your Coolify deployment using either Cloudflare tunnels or custom SSL certificates.

## Overview

VibeStack Coolify now supports two methods for SSL/HTTPS configuration:

1. **Cloudflare Tunnel** (Recommended) - Fully automated tunnel creation with SSL
2. **Custom SSL Certificates** - Use your own certificates (including Cloudflare Origin certificates)

## Option 1: Cloudflare Tunnel (Recommended)

### Benefits
- Fully automated setup
- No firewall ports needed (except SSH)
- Automatic SSL/TLS encryption
- DDoS protection from Cloudflare
- Works behind NAT/firewalls

### Setup
1. Get your Cloudflare credentials:
   - API Token with `Zone:DNS:Edit` and `Account:Cloudflare Tunnel:Edit` permissions
   - Account ID (found in Cloudflare dashboard sidebar)
   - Zone ID (found in domain dashboard)

2. Configure in `terraform.tfvars`:
```hcl
enable_cloudflare_tunnel = true
cloudflare_api_token     = "your-api-token-here"
cloudflare_account_id    = "your-account-id"
cloudflare_zone_id       = "your-zone-id"
tunnel_hostname          = "coolify.yourdomain.com"
ssh_hostname             = "ssh.yourdomain.com"  # Optional
```

## Option 2: Custom SSL Certificates

### Benefits
- Use your existing SSL certificates
- Works with Cloudflare Origin certificates
- No API credentials needed
- Full control over certificate management

### Supported Certificate Types
- Cloudflare Origin Certificates (15-year validity)
- Let's Encrypt certificates
- Commercial SSL certificates
- Self-signed certificates (for testing)

### Setup with Cloudflare Origin Certificate

1. **Generate Origin Certificate in Cloudflare:**
   - Go to SSL/TLS → Origin Server
   - Click "Create Certificate"
   - Choose RSA or ECDSA
   - Add your hostnames (e.g., `*.yourdomain.com`, `yourdomain.com`)
   - Choose validity period (up to 15 years)
   - Click "Create"

2. **Configure in `terraform.tfvars`:**
```hcl
enable_custom_ssl = true
ssl_domain        = "coolify.yourdomain.com"

# Paste the Origin Certificate
ssl_certificate = <<-EOT
-----BEGIN CERTIFICATE-----
[Paste your certificate content here]
-----END CERTIFICATE-----
EOT

# Paste the Private Key
ssl_private_key = <<-EOT
-----BEGIN PRIVATE KEY-----
[Paste your private key content here]
-----END PRIVATE KEY-----
EOT

# Optional: Add Cloudflare Origin CA root certificate
ssl_certificate_chain = <<-EOT
-----BEGIN CERTIFICATE-----
[Paste CA certificate if needed]
-----END CERTIFICATE-----
EOT
```

3. **Configure Cloudflare DNS:**
   - Add an A record pointing to your server's public IP
   - Enable "Proxied" (orange cloud) for Cloudflare protection
   - Set SSL/TLS mode to "Full" or "Full (strict)"

### Setup with Let's Encrypt Certificate

1. **Generate certificate** (on any machine):
```bash
certbot certonly --manual --preferred-challenges dns \
  -d coolify.yourdomain.com \
  -d *.coolify.yourdomain.com
```

2. **Copy certificate contents** to `terraform.tfvars`:
```hcl
enable_custom_ssl = true
ssl_domain        = "coolify.yourdomain.com"

ssl_certificate = <<-EOT
[Contents of /etc/letsencrypt/live/coolify.yourdomain.com/fullchain.pem]
EOT

ssl_private_key = <<-EOT
[Contents of /etc/letsencrypt/live/coolify.yourdomain.com/privkey.pem]
EOT
```

## How It Works

### Certificate Deployment Process

1. **Terraform** passes certificate data to cloud-init as base64-encoded variables
2. **Cloud-init** writes encoded certificates to `/opt/vibestack-ansible/`
3. **Runcmd** decodes certificates and sets proper permissions
4. **Ansible playbook**:
   - Copies certificates to `/data/coolify/proxy/certs/`
   - Creates fullchain certificate if chain is provided
   - Restarts Coolify to apply certificates
   - Configures Traefik (if running) to use the certificates

### Certificate Locations on Server

- `/opt/vibestack-ansible/ssl.crt` - Certificate (temporary)
- `/opt/vibestack-ansible/ssl.key` - Private key (temporary)
- `/data/coolify/proxy/certs/{domain}.crt` - Final certificate location
- `/data/coolify/proxy/certs/{domain}.key` - Final private key location
- `/data/coolify/proxy/certs/{domain}-fullchain.crt` - Full certificate chain

## Verification

### After Deployment

1. **Check certificate deployment:**
```bash
ssh ubuntu@your-server-ip
sudo ls -la /data/coolify/proxy/certs/
```

2. **Test HTTPS access:**
```bash
curl -I https://coolify.yourdomain.com
```

3. **Check Traefik status (if using):**
```bash
sudo docker ps | grep coolify-proxy
sudo docker logs coolify-proxy
```

## Troubleshooting

### Certificate Not Working

1. **Check certificate files exist:**
```bash
sudo ls -la /data/coolify/proxy/certs/
```

2. **Verify certificate validity:**
```bash
openssl x509 -in /data/coolify/proxy/certs/yourdomain.crt -text -noout
```

3. **Check Coolify logs:**
```bash
sudo docker logs coolify
```

### Cloudflare Origin Certificate Issues

- Ensure Cloudflare SSL/TLS mode is set to "Full" or "Full (strict)"
- Verify DNS record is proxied (orange cloud)
- Check that certificate includes your domain

### Permission Issues

- Certificates should be owned by root
- Certificate files: 644 permissions
- Private key: 600 permissions

## Security Best Practices

1. **Never commit private keys** to version control
2. **Use Terraform variables** or environment variables for sensitive data
3. **Rotate certificates** before expiration
4. **Use strong key sizes** (RSA 2048+ or ECDSA P-256+)
5. **Enable HSTS** in Coolify after SSL is working

## Updating Certificates

To update certificates after deployment:

1. **SSH to server:**
```bash
ssh ubuntu@your-server-ip
```

2. **Update certificate files:**
```bash
sudo vim /data/coolify/proxy/certs/yourdomain.crt
sudo vim /data/coolify/proxy/certs/yourdomain.key
```

3. **Restart Coolify:**
```bash
sudo docker restart coolify
```

4. **If using Traefik:**
```bash
sudo docker restart coolify-proxy
```

## Support

For issues or questions:
- Check `/var/log/vibestack-setup.log` for deployment logs
- Review `/opt/vibestack-ansible/deployment-success.txt` for configuration details
- Open an issue on GitHub with relevant log excerpts