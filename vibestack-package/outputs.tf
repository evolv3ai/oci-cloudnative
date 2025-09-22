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
  value = {
    display_name   = oci_core_instance.kasm.display_name
    public_ip      = oci_core_instance.kasm.public_ip
    private_ip     = oci_core_instance.kasm.private_ip
    block_volume   = oci_core_volume.kasm_data.id
    block_size_gb  = var.kasm_block_volume_size_in_gbs
    ocpus          = var.kasm_ocpus
    memory_in_gbs  = var.kasm_memory_in_gbs
  }
}

output "coolify_server" {
  value = {
    display_name   = oci_core_instance.coolify.display_name
    public_ip      = oci_core_instance.coolify.public_ip
    private_ip     = oci_core_instance.coolify.private_ip
    block_volume   = oci_core_volume.coolify_data.id
    block_size_gb  = var.coolify_block_volume_size_in_gbs
    ocpus          = var.coolify_ocpus
    memory_in_gbs  = var.coolify_memory_in_gbs
  }
}

output "security_list_ingress_ports" {
  value = [for rule in local.ingress_tcp_ports : rule.port]
}
