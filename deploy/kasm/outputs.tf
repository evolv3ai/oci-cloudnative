output "compartment" {
  value = {
    name = oci_identity_compartment.vibestack.name
    id   = oci_identity_compartment.vibestack.id
  }
}

output "network" {
  value = {
    vcn_name      = local.vcn_name
    vcn_id        = oci_core_virtual_network.free_tier.id
    subnet_name   = local.subnet_name
    subnet_id     = oci_core_subnet.public.id
    cidr_block    = oci_core_virtual_network.free_tier.cidr_block
    subnet_cidr   = oci_core_subnet.public.cidr_block
    security_list = oci_core_security_list.public.id
  }
}

output "kasm_server" {
  value = var.deploy_kasm ? {
    display_name   = oci_core_instance.kasm[0].display_name
    public_ip      = oci_core_instance.kasm[0].public_ip
    private_ip     = oci_core_instance.kasm[0].private_ip
    block_volume   = oci_core_volume.kasm_data[0].id
    block_size_gb  = var.kasm_block_volume_size_in_gbs
    ocpus          = var.kasm_ocpus
    memory_in_gbs  = var.kasm_memory_in_gbs
  } : null
}

output "security_list_ingress_ports" {
  value = [for rule in local.ingress_tcp_ports : rule.port]
}

output "kasm_setup_instructions" {
  value = var.deploy_kasm ? {
    step1 = "SSH to server: ssh -i <your-key> ubuntu@${oci_core_instance.kasm[0].public_ip}"
    step2 = "Run installation: cd /opt/vibestack-ansible && sudo ansible-playbook kasm/install.yml"
    step3 = "SAVE THE PASSWORDS shown in the output!"
    step4 = "Access KASM at: https://${oci_core_instance.kasm[0].public_ip}"
    step5 = "Credentials file: /opt/kasm/credentials.txt"
  } : null
}
