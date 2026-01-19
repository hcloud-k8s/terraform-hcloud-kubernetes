# Longhorn Storage Volumes
# Creates dedicated Hetzner volumes for worker nodes with longhorn_volume_size > 0

locals {
  # Build map of worker nodes that need longhorn volumes
  worker_nodes_with_volumes = merge([
    for np_index in range(length(local.worker_nodepools)) : {
      for wkr_index in range(local.worker_nodepools[np_index].count) :
      "${var.cluster_name}-${local.worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        location             = local.worker_nodepools[np_index].location
        longhorn_volume_size = local.worker_nodepools[np_index].longhorn_volume_size
      }
      if local.worker_nodepools[np_index].longhorn_volume_size > 0
    }
  ]...)
}

# Create volumes for worker nodes with longhorn_volume_size > 0
resource "hcloud_volume" "longhorn" {
  for_each = local.worker_nodes_with_volumes

  name     = "${each.key}-longhorn-vol"
  size     = each.value.longhorn_volume_size
  location = each.value.location
  # Note: Do NOT set format - Talos expects raw disks to partition and format itself

  labels = {
    cluster = var.cluster_name
    role    = "longhorn-storage"
  }

  delete_protection = var.cluster_delete_protection
}

# Attach volumes to worker nodes
resource "hcloud_volume_attachment" "longhorn" {
  for_each = hcloud_volume.longhorn

  volume_id = each.value.id
  server_id = hcloud_server.worker[each.key].id
  automount = false

  depends_on = [hcloud_server.worker]
}
