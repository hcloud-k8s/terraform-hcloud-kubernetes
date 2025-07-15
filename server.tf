resource "hcloud_server" "control_plane" {
  for_each = merge([
    for np_index in range(length(local.control_plane_nodepools)) : {
      for cp_index in range(local.control_plane_nodepools[np_index].count) : "${var.cluster_name}-${local.control_plane_nodepools[np_index].name}-${cp_index + 1}" => {
        server_type        = local.control_plane_nodepools[np_index].server_type,
        location           = local.control_plane_nodepools[np_index].location,
        backups            = local.control_plane_nodepools[np_index].backups,
        keep_disk          = local.control_plane_nodepools[np_index].keep_disk,
        labels             = local.control_plane_nodepools[np_index].labels,
        placement_group_id = hcloud_placement_group.control_plane.id,
        subnet             = hcloud_network_subnet.control_plane,
        ipv4_private = cidrhost(
          hcloud_network_subnet.control_plane.ip_range,
          np_index * 10 + cp_index + 1
        )
      }
    }
  ]...)

  name                     = each.key
  image                    = substr(each.value.server_type, 0, 3) == "cax" ? data.hcloud_image.arm64[0].id : data.hcloud_image.amd64[0].id
  server_type              = each.value.server_type
  location                 = each.value.location
  placement_group_id       = each.value.placement_group_id
  backups                  = each.value.backups
  keep_disk                = each.value.keep_disk
  ssh_keys                 = [hcloud_ssh_key.this.id]
  shutdown_before_deletion = true
  delete_protection        = var.cluster_delete_protection
  rebuild_protection       = var.cluster_delete_protection

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "control-plane"
    }
  )

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = var.talos_public_ipv4_enabled
    ipv6_enabled = var.talos_public_ipv6_enabled
  }

  network {
    network_id = each.value.subnet.network_id
    ip         = each.value.ipv4_private
    alias_ips  = []
  }

  depends_on = [
    hcloud_network_subnet.control_plane,
    hcloud_placement_group.control_plane
  ]

  lifecycle {
    ignore_changes = [
      image,
      network,
      ssh_keys
    ]
  }
}

resource "hcloud_server" "worker" {
  for_each = merge([
    for np_index in range(length(local.worker_nodepools)) : {
      for wkr_index in range(local.worker_nodepools[np_index].count) : "${var.cluster_name}-${local.worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        server_type        = local.worker_nodepools[np_index].server_type,
        location           = local.worker_nodepools[np_index].location,
        backups            = local.worker_nodepools[np_index].backups,
        keep_disk          = local.worker_nodepools[np_index].keep_disk,
        labels             = local.worker_nodepools[np_index].labels,
        placement_group_id = local.worker_nodepools[np_index].placement_group ? hcloud_placement_group.worker["${var.cluster_name}-${local.worker_nodepools[np_index].name}-pg-${ceil((wkr_index + 1) / 10.0)}"].id : null,
        subnet             = hcloud_network_subnet.worker[local.worker_nodepools[np_index].name],
        ipv4_private       = cidrhost(hcloud_network_subnet.worker[local.worker_nodepools[np_index].name].ip_range, wkr_index + 1)
      }
    }
  ]...)

  name                     = each.key
  image                    = substr(each.value.server_type, 0, 3) == "cax" ? data.hcloud_image.arm64[0].id : data.hcloud_image.amd64[0].id
  server_type              = each.value.server_type
  location                 = each.value.location
  placement_group_id       = each.value.placement_group_id
  backups                  = each.value.backups
  keep_disk                = each.value.keep_disk
  ssh_keys                 = [hcloud_ssh_key.this.id]
  shutdown_before_deletion = true
  delete_protection        = var.cluster_delete_protection
  rebuild_protection       = var.cluster_delete_protection

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "worker"
    }
  )

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = var.talos_public_ipv4_enabled
    ipv6_enabled = var.talos_public_ipv6_enabled
  }

  network {
    network_id = each.value.subnet.network_id
    ip         = each.value.ipv4_private
    alias_ips  = []
  }

  depends_on = [
    hcloud_network_subnet.worker,
    hcloud_placement_group.worker
  ]

  lifecycle {
    ignore_changes = [
      image,
      ssh_keys
    ]
  }
}

resource "hcloud_server" "worker_extend" {
  for_each = merge([
    for np_index in range(length(local.extended_worker_nodepools)) : {
      for wkr_index in range(local.extended_worker_nodepools[np_index].count) : "${var.cluster_name}-${local.extended_worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        server_type = local.extended_worker_nodepools[np_index].server_type,
        location    = local.extended_worker_nodepools[np_index].location,
        backups     = local.extended_worker_nodepools[np_index].backups,
        keep_disk   = local.extended_worker_nodepools[np_index].keep_disk,
        labels      = local.extended_worker_nodepools[np_index].labels,
        # placement_group_id = local.extended_worker_nodepools[np_index].placement_group ? hcloud_placement_group.worker["${var.cluster_name}-${local.extended_worker_nodepools[np_index].name}-pg-${ceil((wkr_index + 1) / 10.0)}"].id : null,
        # subnet       = hcloud_network_subnet.worker[local.extended_worker_nodepools[np_index].name],
        # ipv4_private = cidrhost(hcloud_network_subnet.worker[local.extended_worker_nodepools[np_index].name].ip_range, wkr_index + 1)
      }
    }
  ]...)

  name        = each.key
  image       = substr(each.value.server_type, 0, 3) == "cax" ? data.hcloud_image.arm64[0].id : data.hcloud_image.amd64[0].id
  server_type = each.value.server_type
  location    = each.value.location
  # placement_group_id       = each.value.placement_group_id
  backups                  = each.value.backups
  keep_disk                = each.value.keep_disk
  ssh_keys                 = [hcloud_ssh_key.this.id]
  shutdown_before_deletion = true
  delete_protection        = var.cluster_delete_protection
  rebuild_protection       = var.cluster_delete_protection

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "worker"
    }
  )

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = var.talos_public_ipv4_enabled
    ipv6_enabled = var.talos_public_ipv6_enabled
  }

  network {
    # network_id = each.value.subnet.network_id
    network_id = var.hcloud_extend_network_id
    # ip         = each.value.ipv4_private
    alias_ips = []
  }

  depends_on = [
    hcloud_network_subnet.worker,
    hcloud_placement_group.worker
  ]

  lifecycle {
    ignore_changes = [
      image,
      ssh_keys
    ]
  }
}

