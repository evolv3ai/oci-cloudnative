# Termius Import Generator

Automatically generate Termius SSH client import files from your VibeStack Terraform deployment.

## 🚀 Quick Start

After deploying VibeStack with Terraform:

```bash
# Linux/macOS
./generate-termius-import.sh

# Windows PowerShell
.\generate-termius-import.ps1
```

The script will create import files in the `termius-import/` directory.

## 📁 Generated Files

| File | Purpose |
|------|---------|
| `vibestack-termius.csv` | **Primary import file** - Use this for Termius CSV import |
| `vibestack-termius.json` | JSON format import (alternative) |
| `vibestack-ssh-config` | Standard SSH config format |
| `connect.sh` / `connect.ps1` | Quick connect script for command line |

## ⚙️ Configuration

### Environment Variables (.env)

Create a `.env` file to customize the import generation:

```bash
# Copy the example file
cp .env.example .env
# Edit with your preferences
nano .env
```

**Available options:**
```bash
# SSH connection settings
SSH_USERNAME=ubuntu          # Default username for connections
SSH_PORT=22                  # SSH port (usually 22)
SSH_KEY_PATH=~/.ssh/id_rsa   # Path to your SSH private key

# Output settings
OUTPUT_DIR=./termius-import  # Where to save import files
TERRAFORM_DIR=./terraform/vibestack  # Terraform directory to read from
```

### Security Notes

- The `.env` file is automatically ignored by Git
- Never commit SSH keys or sensitive information
- Import files may contain IP addresses - review before sharing

## 📥 Importing to Termius

### Method 1: CSV Import (Recommended)

1. Open Termius
2. Go to **Settings** → **Import & Export** → **Import**
3. Select **CSV** format
4. Choose the generated `vibestack-termius.csv` file
5. Your servers will appear in Termius with proper labels and tags

### Method 2: SSH Config Import

1. In Termius, go to **Settings** → **Import & Export** → **Import**
2. Select **ssh_config** format
3. Choose the generated `vibestack-ssh-config` file

### Method 3: Manual SSH Config

Add the contents of `vibestack-ssh-config` to your `~/.ssh/config` file:

```bash
# Linux/macOS
cat termius-import/vibestack-ssh-config >> ~/.ssh/config

# Windows (Git Bash/WSL)
cat termius-import/vibestack-ssh-config >> ~/.ssh/config
```

## 🖥️ Server Information

The script automatically detects which servers are deployed:

### KASM Workspaces Server
- **Purpose**: Browser-based remote desktops
- **Access**: `https://[KASM-IP]`
- **Resources**: 2 OCPUs, 12GB RAM, 60GB storage
- **Default Login**: Admin panel setup required on first visit

### Coolify Server
- **Purpose**: Self-hosted application deployment platform
- **Access**: `http://[COOLIFY-IP]:3000`
- **Resources**: 2 OCPUs, 12GB RAM, 100GB storage
- **Default Login**: Setup required on first visit

## 🔧 Advanced Usage

### Custom SSH Keys

If you're using a different SSH key for OCI:

```bash
# In your .env file
SSH_KEY_PATH=~/.ssh/oci-vibestack-key
```

### Different Operating Systems

If you deployed with Oracle Linux instead of Ubuntu:

```bash
# In your .env file
SSH_USERNAME=opc
```

### Multiple Deployments

For multiple VibeStack deployments, specify different Terraform directories:

```bash
# Generate imports for a specific deployment
./generate-termius-import.sh --terraform-dir ./terraform/production-vibestack
```

## 📋 Prerequisites

### Required Tools

**Linux/macOS:**
- `bash` (usually pre-installed)
- `terraform` (for reading outputs)
- `jq` (for JSON parsing)

```bash
# Install jq if missing
# Ubuntu/Debian
sudo apt update && sudo apt install jq

# macOS
brew install jq
```

**Windows:**
- PowerShell 5.1+ (usually pre-installed)
- `terraform` (for reading outputs)

### Terraform State

The script reads from Terraform outputs, so you need:
1. A successful `terraform apply` in your chosen directory
2. Terraform state files present
3. At least one server deployed (KASM or Coolify)

## 🐛 Troubleshooting

### "No Terraform outputs found"
- Ensure you've run `terraform apply` successfully
- Check that you're in the correct directory
- Verify the `TERRAFORM_DIR` setting in your `.env`

### "No servers found"
- Check that your Terraform deployment includes at least one server
- Verify that `deploy_kasm` or `deploy_coolify` variables are set to `true`
- Check Terraform outputs: `terraform output -json`

### Permission Denied (Linux/macOS)
```bash
chmod +x generate-termius-import.sh
```

### PowerShell Execution Policy (Windows)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🔗 Integration

### CI/CD Pipelines

The script can be used in automation:

```yaml
# GitHub Actions example
- name: Generate Termius imports
  run: |
    ./generate-termius-import.sh

- name: Upload artifacts
  uses: actions/upload-artifact@v3
  with:
    name: termius-imports
    path: termius-import/
```

### Terraform Integration

Add as a local-exec provisioner:

```hcl
resource "null_resource" "generate_termius_import" {
  depends_on = [oci_core_instance.kasm, oci_core_instance.coolify]

  provisioner "local-exec" {
    command = "./generate-termius-import.sh"
  }
}
```