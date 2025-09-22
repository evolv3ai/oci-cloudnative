resource "oci_core_virtual_network" "free_tier" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = oci_identity_compartment.vibestack.id
  display_name   = local.vcn_name
  dns_label      = local.vcn_dns_label
}

resource "oci_core_internet_gateway" "free_tier" {
  compartment_id = oci_identity_compartment.vibestack.id
  display_name   = local.igw_name
  vcn_id         = oci_core_virtual_network.free_tier.id
}

resource "oci_core_route_table" "public" {
  compartment_id = oci_identity_compartment.vibestack.id
  display_name   = local.route_table_name
  vcn_id         = oci_core_virtual_network.free_tier.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.free_tier.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = oci_identity_compartment.vibestack.id
  display_name   = local.security_list_name
  vcn_id         = oci_core_virtual_network.free_tier.id

  dynamic "ingress_security_rules" {
    for_each = local.ingress_tcp_ports
    content {
      protocol    = "6"
      source      = "0.0.0.0/0"
      source_type = "CIDR_BLOCK"
      description = ingress_security_rules.value.description

      tcp_options {
        min = ingress_security_rules.value.port
        max = ingress_security_rules.value.port
      }
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "Allow all outbound traffic"
  }
}

resource "oci_core_subnet" "public" {
  availability_domain = null
  cidr_block          = "10.0.1.0/24"
  compartment_id      = oci_identity_compartment.vibestack.id
  display_name        = local.subnet_name
  dns_label           = local.subnet_dns_label
  route_table_id      = oci_core_route_table.public.id
  security_list_ids   = [oci_core_security_list.public.id]
  vcn_id              = oci_core_virtual_network.free_tier.id

  prohibit_public_ip_on_vnic = var.assign_public_ip ? false : true
}
