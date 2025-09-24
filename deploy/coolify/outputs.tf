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

output "coolify_server" {
  value = var.deploy_coolify ? {
    display_name   = oci_core_instance.coolify[0].display_name
    public_ip      = oci_core_instance.coolify[0].public_ip
    private_ip     = oci_core_instance.coolify[0].private_ip
    block_volume   = oci_core_volume.coolify_data[0].id
    block_size_gb  = var.coolify_block_volume_size_in_gbs
    ocpus          = var.coolify_ocpus
    memory_in_gbs  = var.coolify_memory_in_gbs
  } : null
}

output "security_list_ingress_ports" {
  value = [for rule in local.ingress_tcp_ports : rule.port]
}
