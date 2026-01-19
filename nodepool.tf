locals {
  control_plane_nodepools = [
    for np in var.control_plane_nodepools : {
      name        = np.name,
      location    = np.location,
      server_type = np.type,
      backups     = np.backups,
      keep_disk   = np.keep_disk,
      rdns_ipv4 = var.talos_public_ipv4_enabled ? (
        np.rdns_ipv4 != null ? np.rdns_ipv4 :
        np.rdns != null ? np.rdns :
        local.cluster_rdns_ipv4
      ) : null,
      rdns_ipv6 = var.talos_public_ipv6_enabled ? (
        np.rdns_ipv6 != null ? np.rdns_ipv6 :
        np.rdns != null ? np.rdns :
        local.cluster_rdns_ipv6
      ) : null,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = concat(
        [for taint in np.taints : regex(
          "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
          taint
        )],
        local.talos_allow_scheduling_on_control_planes ? [] : [
          { key = "node-role.kubernetes.io/control-plane", value = "", effect = "NoSchedule" }
        ]
      ),
      count = np.count,
    }
  ]

  worker_nodepools = [
    for np in var.worker_nodepools : {
      name        = np.name,
      location    = np.location,
      server_type = np.type,
      backups     = np.backups,
      keep_disk   = np.keep_disk,
      rdns_ipv4 = var.talos_public_ipv4_enabled ? (
        np.rdns_ipv4 != null ? np.rdns_ipv4 :
        np.rdns != null ? np.rdns :
        local.cluster_rdns_ipv4
      ) : null,
      rdns_ipv6 = var.talos_public_ipv6_enabled ? (
        np.rdns_ipv6 != null ? np.rdns_ipv6 :
        np.rdns != null ? np.rdns :
        local.cluster_rdns_ipv6
      ) : null,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = [for taint in np.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )],
      count                = np.count,
      placement_group      = np.placement_group,
      longhorn_volume_size = np.longhorn_volume_size
    }
  ]

  cluster_autoscaler_nodepools = [
    for np in var.cluster_autoscaler_nodepools : {
      name        = np.name,
      location    = np.location,
      server_type = np.type,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = [for taint in np.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )],
      min = np.min,
      max = np.max
    }
  ]

  control_plane_nodepools_map      = { for np in local.control_plane_nodepools : np.name => np }
  worker_nodepools_map             = { for np in local.worker_nodepools : np.name => np }
  cluster_autoscaler_nodepools_map = { for np in local.cluster_autoscaler_nodepools : np.name => np }

  control_plane_sum = sum(concat(
    [for np in local.control_plane_nodepools : np.count], [0]
  ))
  worker_sum = sum(concat(
    [for np in local.worker_nodepools : np.count if length(np.taints) == 0], [0]
  ))
  cluster_autoscaler_min_sum = sum(concat(
    [for np in local.cluster_autoscaler_nodepools : np.min if length(np.taints) == 0], [0]
  ))
  cluster_autoscaler_max_sum = sum(concat(
    [for np in local.cluster_autoscaler_nodepools : np.max if length(np.taints) == 0], [0]
  ))
}
