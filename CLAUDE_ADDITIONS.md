# CLAUDE.md Additions

## Add after line 77 (Ansible Integration section):

### Testing Ansible Without Full Rebuilds

For rapid Ansible development, use the test workflow:

1. **Deploy once** with Ansible disabled in cloud-init
2. **Sync changes** via rsync to running instance  
3. **Test repeatedly** without destroying infrastructure
4. **See TEST_WORKFLOW.md** for detailed instructions

This avoids the slow cycle of: commit → release → deploy → test

## Add new section before "Release Process":

## Development Testing

### Ansible Testing Mode
- Use test-ansible branch for development
- Comment out auto-execution in cloud-init
- Sync files directly: rsync -avz ./ansible/ ubuntu@<IP>:/opt/vibestack/
- Test without rebuilding: terraform apply once, iterate many times

### Local Validation
```bash
# Check Ansible syntax
ansible-playbook --syntax-check ansible/kasm/install.yml

# Validate YAML
yamllint deploy/kasm/*.yaml

# Test locally with Docker (ARM64)
docker run -it --privileged ubuntu:22.04
```
