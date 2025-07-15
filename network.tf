locals {
  network_public_ipv4_enabled = var.talos_public_ipv4_enabled
  network_public_ipv6_enabled = var.talos_public_ipv6_enabled && var.talos_ipv6_enabled

  hcloud_network_id = length(data.hcloud_network.this) > 0 ? data.hcloud_network.this[0].id : hcloud_network.this[0].id

  location_to_zone = {
    fsn1 = "eu-central"
    nbg1 = "eu-central"
    hel1 = "eu-central"
    ash  = "us-east"
    hil  = "us-west"
    sin  = "ap-southeast"
  }
  network_zone = local.location_to_zone[local.control_plane_nodepools[0].location]

  # Network ranges
  network_ipv4_cidr   = length(data.hcloud_network.this) > 0 ? data.hcloud_network.this[0].ip_range : var.network_ipv4_cidr
  node_ipv4_cidr      = coalesce(var.network_node_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 3, 2))
  service_ipv4_cidr   = coalesce(var.network_service_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 3, 3))
  pod_ipv4_cidr       = coalesce(var.network_pod_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 1, 1))
  native_routing_cidr = coalesce(var.network_native_routing_cidr, local.network_ipv4_cidr)

  node_ipv4_cidr_skip_first_subnet = cidrhost(local.network_ipv4_cidr, 0) == cidrhost(local.node_ipv4_cidr, 0)
  network_ipv4_gateway             = cidrhost(local.network_ipv4_cidr, 1)

  # Subnet mask sizes
  network_pod_ipv4_subnet_mask_size = 24
  network_node_ipv4_subnet_mask_size = coalesce(
    var.network_node_ipv4_subnet_mask_size,
    32 - (local.network_pod_ipv4_subnet_mask_size - split("/", local.pod_ipv4_cidr)[1])
  )

  # Lists for control plane nodes
  control_plane_public_ipv4_list        = [for server in hcloud_server.control_plane : server.ipv4_address]
  control_plane_public_ipv6_list        = [for server in hcloud_server.control_plane : server.ipv6_address]
  control_plane_public_ipv6_subnet_list = [for server in hcloud_server.control_plane : server.ipv6_network]
  control_plane_private_ipv4_list       = [for server in hcloud_server.control_plane : tolist(server.network)[0].ip]

  # Control plane VIPs
  control_plane_public_vip_ipv4  = local.control_plane_public_vip_ipv4_enabled ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null
  control_plane_private_vip_ipv4 = cidrhost(hcloud_network_subnet.control_plane.ip_range, -2)

  # Lists for worker nodes
  worker_public_ipv4_list        = [for server in hcloud_server.worker : server.ipv4_address]
  worker_public_ipv6_list        = [for server in hcloud_server.worker : server.ipv6_address]
  worker_public_ipv6_subnet_list = [for server in hcloud_server.worker : server.ipv6_network]
  worker_private_ipv4_list       = [for server in hcloud_server.worker : tolist(server.network)[0].ip]
}

data "hcloud_network" "this" {
  count = var.hcloud_network != null || var.hcloud_network_id != null ? 1 : 0

  id = var.hcloud_network != null ? var.hcloud_network.id : var.hcloud_network_id
}

data "hcloud_network" "this_extend" {
  count = var.hcloud_network != null || var.hcloud_network_id != null ? 1 : 0

  id = var.hcloud_network != null ? var.hcloud_network.id : var.hcloud_network_id
}

resource "hcloud_network" "this" {
  count = length(data.hcloud_network.this) > 0 ? 0 : 1

  name              = var.cluster_name
  ip_range          = local.network_ipv4_cidr
  delete_protection = var.cluster_delete_protection

  labels = {
    cluster = var.cluster_name
  }
}

resource "hcloud_network_subnet" "control_plane" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.network_zone

  ip_range = cidrsubnet(
    local.node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
    0 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0)
  )
}

resource "hcloud_network_subnet" "load_balancer" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.network_zone

  ip_range = cidrsubnet(
    local.node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
    1 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0)
  )
}

resource "hcloud_network_subnet" "worker" {
  for_each = { for np in local.worker_nodepools : np.name => np }

  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.network_zone

  ip_range = cidrsubnet(
    local.node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
    2 + (local.node_ipv4_cidr_skip_first_subnet ? 1 : 0) + index(local.worker_nodepools, each.value)
  )
}

resource "hcloud_network_subnet" "autoscaler" {
  network_id   = local.hcloud_network_id
  type         = "cloud"
  network_zone = local.network_zone

  ip_range = cidrsubnet(
    local.node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1],
    pow(2, local.network_node_ipv4_subnet_mask_size - split("/", local.node_ipv4_cidr)[1]) - 1
  )

  depends_on = [
    hcloud_network_subnet.control_plane,
    hcloud_network_subnet.load_balancer,
    hcloud_network_subnet.worker
  ]
}

