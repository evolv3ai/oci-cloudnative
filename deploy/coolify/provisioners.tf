# Terraform null_resource to wait for Ansible setup completion
# This ensures Terraform waits for cloud-init and Ansible to finish

resource "null_resource" "wait_for_ansible_coolify" {
  count = var.deploy_coolify ? 1 : 0

  depends_on = [
    oci_core_instance.coolify,
    oci_core_volume_attachment.coolify
  ]

  # Wait for cloud-init to complete and Ansible setup marker file
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait",
      "echo 'Cloud-init completed. Waiting for Ansible setup...'",
      "timeout 1800 bash -c 'until [ -f /opt/vibestack-ansible/setup-complete ]; do echo \"Waiting for Ansible setup...\"; sleep 10; done'",
      "echo 'Ansible setup completed successfully!'",
      "cat /opt/vibestack-ansible/setup-complete"
    ]

    connection {
      type        = "ssh"
      host        = var.assign_public_ip ? oci_core_instance.coolify[0].public_ip : oci_core_instance.coolify[0].private_ip
      user        = "ubuntu"
      private_key = var.private_key_path != "" ? file(var.private_key_path) : null
      timeout     = "30m"
    }
  }

  triggers = {
    instance_id = oci_core_instance.coolify[0].id
  }
}