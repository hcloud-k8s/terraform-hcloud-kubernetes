locals {
  control_plane_public_vip_ipv4_enabled = (
    local.network_public_ipv4_enabled && (
      var.control_plane_public_vip_ipv4_id != null ||
      var.control_plane_public_vip_ipv4_enabled
    )
  )
  control_plane_public_vip_ipv6_enabled = (
    local.network_public_ipv6_enabled && (
      var.control_plane_public_vip_ipv6_id != null ||
      var.control_plane_public_vip_ipv6_enabled
    )
  )
}

resource "hcloud_floating_ip" "control_plane_ipv4" {
  count = local.control_plane_public_vip_ipv4_enabled && var.control_plane_public_vip_ipv4_id == null ? 1 : 0

  name              = "${var.cluster_name}-control-plane-ipv4"
  type              = "ipv4"
  home_location     = hcloud_server.control_plane[local.talos_primary_node_name].location
  description       = "Control Plane Public VIPv4"
  delete_protection = var.cluster_delete_protection

  labels = {
    cluster = var.cluster_name,
    role    = "control-plane"
  }
}

resource "hcloud_floating_ip" "control_plane_ipv6" {
  count = local.control_plane_public_vip_ipv6_enabled && var.control_plane_public_vip_ipv6_id == null ? 1 : 0

  name              = "${var.cluster_name}-control-plane-ipv6"
  type              = "ipv6"
  home_location     = hcloud_server.control_plane[local.talos_primary_node_name].location
  description       = "Control Plane Public VIPv6"
  delete_protection = var.cluster_delete_protection

  labels = {
    cluster = var.cluster_name,
    role    = "control-plane"
  }
}

data "hcloud_floating_ip" "control_plane_ipv4" {
  count = local.control_plane_public_vip_ipv4_enabled ? 1 : 0

  id = coalesce(
    can(var.control_plane_public_vip_ipv4_id) ? var.control_plane_public_vip_ipv4_id : null,
    local.control_plane_public_vip_ipv4_enabled ? try(hcloud_floating_ip.control_plane_ipv4[0].id, null) : null
  )
}

data "hcloud_floating_ip" "control_plane_ipv6" {
  count = local.control_plane_public_vip_ipv6_enabled ? 1 : 0

  id = coalesce(
    can(var.control_plane_public_vip_ipv6_id) ? var.control_plane_public_vip_ipv6_id : null,
    local.control_plane_public_vip_ipv6_enabled ? try(hcloud_floating_ip.control_plane_ipv6[0].id, null) : null
  )
}
