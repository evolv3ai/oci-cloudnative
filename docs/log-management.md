# Deployment Log Management

Securely manage Terraform state files and deployment logs for VibeStack.

## 🔒 Security Overview

Your deployment logs contain sensitive information that should **never be committed to Git**:
- Server IP addresses (public and private)
- OCI resource OCIDs
- Compartment details
- Deployment metadata

The log management system provides a **secure workflow** to:
1. Store logs safely in a Git-ignored directory
2. Generate import files from stored logs
3. Securely delete logs when no longer needed

## 📁 Directory Structure

```
vibestack/
├── logs/                    # 🔒 Git-ignored, secure storage
│   ├── README.md           # Security documentation
│   ├── terraform-state-*.txt   # Your deployment logs
│   └── servers-*.env       # Extracted server info
├── termius-import/         # 🔒 Git-ignored, generated imports
└── manage-deployment-logs.*  # Log management scripts
```

## 🚀 Quick Workflow

### 1. Save Your Deployment Log

After running `terraform apply`, save the output or state:

```bash
# Linux/macOS
./manage-deployment-logs.sh save-state path/to/your/terraform-state.txt

# Windows PowerShell
.\manage-deployment-logs.ps1 save-state C:\path\to\your\terraform-state.txt
```

**Examples:**
```bash
# From a saved Terraform state export
./manage-deployment-logs.sh save-state ~/Downloads/vibestack-terraform-state.txt

# From a copied OCI Resource Manager output
./manage-deployment-logs.sh save-state deployment-output.json
```

### 2. Generate Termius Import Files

```bash
# Linux/macOS
./manage-deployment-logs.sh import-from-log

# Windows PowerShell
.\manage-deployment-logs.ps1 import-from-log
```

### 3. Import to Termius

Use the generated files in `termius-import/`:
- **`vibestack-termius.csv`** - Primary import file
- **`vibestack-termius.json`** - Alternative format
- **`vibestack-ssh-config`** - SSH config format

### 4. Secure Cleanup

After importing to Termius and saving any needed info:

```bash
# Linux/macOS
./manage-deployment-logs.sh cleanup

# Windows PowerShell
.\manage-deployment-logs.ps1 cleanup
```

## 📋 Commands Reference

### Save State File
```bash
manage-deployment-logs save-state [file]
```
- Copies log file to secure `logs/` directory
- Adds timestamp to filename
- Extracts server information automatically
- Creates `.env` file with server IPs

### Import from Log
```bash
manage-deployment-logs import-from-log
```
- Uses most recent log file
- Generates all Termius import formats
- Works without live Terraform state

### List Logs
```bash
manage-deployment-logs list
```
- Shows all saved log files
- Displays file sizes and dates
- Helps track what you have stored

### Cleanup Logs
```bash
manage-deployment-logs cleanup
```
- **Securely deletes** all log files
- Requires confirmation (`yes`)
- Overwrites files before deletion (Linux/macOS)
- Cannot be undone - make sure you have imports first!

### Show Paths
```bash
manage-deployment-logs show-paths
```
- Shows directory structure
- Confirms security status
- Displays complete workflow

## 🔧 Advanced Usage

### Different Log Formats

The system handles multiple log formats:

**Terraform State Export:**
```json
{
  "version": 4,
  "terraform_version": "1.5.7",
  "outputs": {
    "kasm_server": {
      "value": {
        "public_ip": "150.136.241.1",
        "private_ip": "10.0.1.176"
      }
    }
  }
}
```

**OCI Resource Manager Output:**
```json
{
  "kasm_server": {
    "value": {
      "public_ip": "150.136.241.1"
    }
  }
}
```

### Manual Server Info Extraction

If automatic extraction fails, manually create a `.env` file in `logs/`:

```bash
# logs/servers-manual.env
COMPARTMENT_NAME=vibestack
KASM_SERVER_IP=150.136.241.1
COOLIFY_SERVER_IP=132.145.209.240
SSH_USERNAME=ubuntu
SSH_PORT=22
SSH_KEY_PATH=~/.ssh/id_rsa
```

### Integration with CI/CD

Use environment variables to automate the process:

```bash
# Set log file location
export VIBESTACK_LOG_FILE=./logs/terraform-state-20240922-081530.txt

# Generate imports
./generate-termius-import.sh
```

## 🛡️ Security Best Practices

### What to Save
✅ **Safe to save:**
- Terraform state exports
- OCI Resource Manager outputs
- Deployment logs from CI/CD

❌ **Never save:**
- SSH private keys
- OCI API credentials
- Terraform `.tfvars` files with secrets

### When to Cleanup
**Clean up logs after:**
- ✅ Successfully importing servers to Termius
- ✅ Saving any needed server information elsewhere
- ✅ Confirming you can reconnect to servers

**Don't clean up if:**
- ❌ You haven't tested the Termius import yet
- ❌ You might need to re-deploy soon
- ❌ You're troubleshooting connection issues

### File Permissions

The scripts automatically secure the logs directory:
- Git ignores all files in `logs/`
- Generated import files are also ignored
- README files explain security to future users

## 🐛 Troubleshooting

### "No log files found"
- Ensure you've run `save-state` first
- Check that files exist: `ls logs/`
- Verify file isn't empty or corrupted

### "Could not parse server info"
- Log file might be in unexpected format
- Try manually creating a `.env` file
- Check that log contains `"kasm_server"` or `"coolify_server"`

### Import generation fails
- Ensure `jq` is installed (Linux/macOS)
- Check that Terraform outputs are valid JSON
- Try manual import with specific log file

### Files not Git-ignored
- Verify `.gitignore` contains `logs/` and `termius-import/`
- Check you're in the correct repository root
- Use `git status` to confirm files aren't tracked

## 🔗 Related Documentation

- [Termius Import Generator](termius-import.md) - Details on import file generation
- [VibeStack Setup Guide](oci-vibestack-recommended-setup.md) - Main deployment process
- [Deploy Button Specification](deploy-button-specification.md) - OCI Resource Manager details