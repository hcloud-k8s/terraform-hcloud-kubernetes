resource "hcloud_placement_group" "control_plane" {
  name = "${var.cluster_name}-control-plane-pg"
  type = "spread"

  labels = {
    cluster = var.cluster_name,
    role    = "control-plane"
  }
}

resource "hcloud_placement_group" "worker" {
  for_each = merge([
    for np in local.worker_nodepools : {
      for i in range(ceil(np.count / 10.0)) : "${var.cluster_name}-${np.name}-pg-${i + 1}" => {
        nodepool = np.name
      }
    } if np.placement_group && np.count > 0
  ]...)

  name = each.key
  type = "spread"

  labels = {
    cluster  = var.cluster_name,
    nodepool = each.value.nodepool,
    role     = "worker"
  }
}

resource "hcloud_placement_group" "cluster_autoscaler" {
  for_each = { for np in local.cluster_autoscaler_nodepools : np.name => np if np.placement_group }

  name = "${var.cluster_name}-${each.key}-pg"
  type = "spread"

  labels = {
    cluster  = var.cluster_name,
    nodepool = each.key,
    role     = "worker"
  }
}
