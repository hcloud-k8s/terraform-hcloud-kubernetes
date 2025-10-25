locals {
  hcloud_load_balancer_location = coalesce(
    var.hcloud_load_balancer_location,
    length(local.worker_nodepools) > 0 ? local.worker_nodepools[0].location : null,
    length(local.cluster_autoscaler_nodepools) > 0 ? local.cluster_autoscaler_nodepools[0].location : null,
    local.control_plane_nodepools[0].location
  )
}

# Kubernetes API Load Balancer
locals {
  kube_api_load_balancer_private_ipv4 = cidrhost(hcloud_network_subnet.load_balancer.ip_range, -2)
  kube_api_load_balancer_public_ipv4  = var.kube_api_load_balancer_enabled ? hcloud_load_balancer.kube_api[0].ipv4 : null
  kube_api_load_balancer_public_ipv6  = var.kube_api_load_balancer_enabled ? hcloud_load_balancer.kube_api[0].ipv6 : null
  kube_api_load_balancer_name         = "${var.cluster_name}-kube-api"
  kube_api_load_balancer_location     = local.control_plane_nodepools[0].location

  kube_api_load_balancer_public_network_enabled = coalesce(
    var.kube_api_load_balancer_public_network_enabled,
    var.cluster_access == "public"
  )
}

resource "hcloud_load_balancer" "kube_api" {
  count = var.kube_api_load_balancer_enabled ? 1 : 0

  name               = local.kube_api_load_balancer_name
  location           = local.kube_api_load_balancer_location
  load_balancer_type = "lb11"
  delete_protection  = var.cluster_delete_protection

  algorithm {
    type = "round_robin"
  }

  labels = {
    cluster = var.cluster_name
    role    = "kube-api"
  }
}

resource "hcloud_load_balancer_network" "kube_api" {
  count = var.kube_api_load_balancer_enabled ? 1 : 0

  load_balancer_id        = hcloud_load_balancer.kube_api[0].id
  enable_public_interface = local.kube_api_load_balancer_public_network_enabled
  subnet_id               = hcloud_network_subnet.load_balancer.id
  ip                      = local.kube_api_load_balancer_private_ipv4

  depends_on = [hcloud_network_subnet.load_balancer]
}

resource "hcloud_load_balancer_target" "kube_api" {
  count = var.kube_api_load_balancer_enabled ? 1 : 0

  load_balancer_id = hcloud_load_balancer.kube_api[0].id
  use_private_ip   = true

  type = "label_selector"
  label_selector = join(",",
    [
      "cluster=${var.cluster_name}",
      "role=control-plane"
    ]
  )

  lifecycle {
    replace_triggered_by = [
      hcloud_load_balancer_network.kube_api
    ]
  }

  depends_on = [hcloud_load_balancer_network.kube_api]
}

resource "hcloud_load_balancer_service" "kube_api" {
  count = var.kube_api_load_balancer_enabled ? 1 : 0

  load_balancer_id = hcloud_load_balancer.kube_api[0].id
  protocol         = "tcp"
  listen_port      = local.kube_api_port
  destination_port = local.kube_api_port

  health_check {
    protocol = "http"
    port     = local.kube_api_port
    interval = 3
    timeout  = 2
    retries  = 2

    http {
      path         = "/version"
      response     = "Status"
      tls          = true
      status_codes = ["401"]
    }
  }

  depends_on = [hcloud_load_balancer_target.kube_api]
}

# Ingress Service Load Balancer
locals {
  ingress_service_load_balancer_required = (
    (local.ingress_nginx_enabled || local.ingress_cilium_enabled) &&
    length(var.ingress_load_balancer_pools) == 0
  )
  ingress_service_type = (
    local.ingress_service_load_balancer_required ?
    "LoadBalancer" :
    "NodePort"
  )

  ingress_service_load_balancer_private_ipv4 = cidrhost(hcloud_network_subnet.load_balancer.ip_range, -4)
  ingress_service_load_balancer_public_ipv4  = local.ingress_service_load_balancer_required ? hcloud_load_balancer.ingress[0].ipv4 : null
  ingress_service_load_balancer_public_ipv6  = local.ingress_service_load_balancer_required ? hcloud_load_balancer.ingress[0].ipv6 : null
  ingress_service_load_balancer_hostname     = local.ingress_service_load_balancer_required ? "static.${join(".", reverse(split(".", local.ingress_service_load_balancer_public_ipv4)))}.clients.your-server.de" : ""
  ingress_service_load_balancer_name         = "${var.cluster_name}-ingress"
  ingress_service_load_balancer_location     = local.hcloud_load_balancer_location
}

resource "hcloud_load_balancer" "ingress" {
  count = local.ingress_service_load_balancer_required ? 1 : 0

  name               = local.ingress_service_load_balancer_name
  location           = local.ingress_service_load_balancer_location
  load_balancer_type = var.ingress_load_balancer_type
  delete_protection  = var.cluster_delete_protection

  algorithm {
    type = var.ingress_load_balancer_algorithm
  }

  labels = {
    cluster = var.cluster_name
    role    = "ingress"
  }

  lifecycle {
    ignore_changes = [
      labels
    ]
  }
}

resource "hcloud_load_balancer_network" "ingress" {
  count = local.ingress_service_load_balancer_required ? 1 : 0

  load_balancer_id        = hcloud_load_balancer.ingress[0].id
  enable_public_interface = var.ingress_load_balancer_public_network_enabled
  subnet_id               = hcloud_network_subnet.load_balancer.id
  ip                      = local.ingress_service_load_balancer_private_ipv4

  depends_on = [hcloud_network_subnet.load_balancer]
}

# Ingress Load Balancer Pools
locals {
  ingress_load_balancer_pools = [
    for lp in var.ingress_load_balancer_pools : {
      name               = lp.name
      location           = lp.location
      load_balancer_type = coalesce(lp.type, var.ingress_load_balancer_type)
      count              = lp.count
      labels = merge(
        lp.labels,
        { pool = lp.name }
      )
      rdns_ipv4 = (
        lp.rdns_ipv4 != null ? lp.rdns_ipv4 :
        lp.rdns != null ? lp.rdns :
        local.ingress_load_balancer_rdns_ipv4
      )
      rdns_ipv6 = (
        lp.rdns_ipv6 != null ? lp.rdns_ipv6 :
        lp.rdns != null ? lp.rdns :
        local.ingress_load_balancer_rdns_ipv6
      )
      target_label_selector = length(lp.target_label_selector) > 0 ? lp.target_label_selector : concat(
        [
          for np in concat(
            local.talos_allow_scheduling_on_control_planes ? local.control_plane_nodepools : [],
            local.worker_nodepools
          ) : "cluster=${var.cluster_name},nodepool=${np.labels.nodepool}"
          if(lp.local_traffic ? np.location == lp.location : true) &&
          lookup(np.labels, "node.kubernetes.io/exclude-from-external-load-balancers", null) == null
        ],
        [
          for np in local.cluster_autoscaler_nodepools :
          "hcloud/node-group=${var.cluster_name}-${np.name}"
          if(lp.local_traffic ? np.location == lp.location : true) &&
          lookup(np.labels, "node.kubernetes.io/exclude-from-external-load-balancers", null) == null
        ]
      )
      load_balancer_algorithm = coalesce(lp.load_balancer_algorithm, var.ingress_load_balancer_algorithm)
      public_network_enabled  = coalesce(lp.public_network_enabled, var.ingress_load_balancer_public_network_enabled)
    }
  ]
  ingress_load_balancer_pools_map = { for lp in local.ingress_load_balancer_pools : lp.name => lp }

  ingress_load_balancer_annotations = {
    "load-balancer.hetzner.cloud/algorithm-type"          = var.ingress_load_balancer_algorithm
    "load-balancer.hetzner.cloud/disable-private-ingress" = "true"
    "load-balancer.hetzner.cloud/disable-public-network"  = tostring(!var.ingress_load_balancer_public_network_enabled)
    "load-balancer.hetzner.cloud/health-check-interval"   = "${var.ingress_load_balancer_health_check_interval}s"
    "load-balancer.hetzner.cloud/health-check-retries"    = tostring(var.ingress_load_balancer_health_check_retries)
    "load-balancer.hetzner.cloud/health-check-timeout"    = "${var.ingress_load_balancer_health_check_timeout}s"
    "load-balancer.hetzner.cloud/hostname"                = local.ingress_service_load_balancer_hostname
    "load-balancer.hetzner.cloud/ipv6-disabled"           = "false"
    "load-balancer.hetzner.cloud/location"                = local.ingress_service_load_balancer_location
    "load-balancer.hetzner.cloud/name"                    = local.ingress_service_load_balancer_name
    "load-balancer.hetzner.cloud/type"                    = var.ingress_load_balancer_type
    "load-balancer.hetzner.cloud/use-private-ip"          = "true"
    "load-balancer.hetzner.cloud/uses-proxyprotocol"      = "true"
  }

}

resource "hcloud_load_balancer" "ingress_pool" {
  for_each = merge([
    for pool_index in range(length(local.ingress_load_balancer_pools)) : {
      for lb_index in range(local.ingress_load_balancer_pools[pool_index].count) : "${var.cluster_name}-${local.ingress_load_balancer_pools[pool_index].name}-${lb_index + 1}" => {
        location                = local.ingress_load_balancer_pools[pool_index].location,
        load_balancer_type      = local.ingress_load_balancer_pools[pool_index].load_balancer_type,
        load_balancer_algorithm = local.ingress_load_balancer_pools[pool_index].load_balancer_algorithm,
        labels                  = local.ingress_load_balancer_pools[pool_index].labels
      }
    }
  ]...)

  name               = each.key
  location           = each.value.location
  load_balancer_type = each.value.load_balancer_type

  algorithm {
    type = each.value.load_balancer_algorithm
  }

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "ingress"
    }
  )
}

resource "hcloud_load_balancer_network" "ingress_pool" {
  for_each = merge([
    for pool_index in range(length(local.ingress_load_balancer_pools)) : {
      for lb_index in range(local.ingress_load_balancer_pools[pool_index].count) : "${var.cluster_name}-${local.ingress_load_balancer_pools[pool_index].name}-${lb_index + 1}" => {
        public_network_enabled = local.ingress_load_balancer_pools[pool_index].public_network_enabled
        ipv4_private = cidrhost(
          hcloud_network_subnet.load_balancer.ip_range,
          -5 - lb_index - (
            pool_index > 0 ?
            sum([for prior_pool_index in range(0, pool_index) : local.ingress_load_balancer_pools[prior_pool_index].count]) :
            0
          )
        )
      }
    }
  ]...)

  load_balancer_id        = hcloud_load_balancer.ingress_pool[each.key].id
  enable_public_interface = each.value.public_network_enabled
  subnet_id               = hcloud_network_subnet.load_balancer.id
  ip                      = each.value.ipv4_private
}

resource "hcloud_load_balancer_target" "ingress_pool" {
  for_each = {
    for entry in flatten([
      for pool in local.ingress_load_balancer_pools : [
        for lb_index in range(pool.count) : [
          for target_index, target_label_selector in pool.target_label_selector : {
            key = "${var.cluster_name}-${pool.name}-${lb_index + 1}-${target_index + 1}"
            value = {
              lb_name        = "${var.cluster_name}-${pool.name}-${lb_index + 1}"
              label_selector = target_label_selector
            }
          }
        ]
      ]
    ]) : entry.key => entry.value
  }

  load_balancer_id = hcloud_load_balancer.ingress_pool[each.value.lb_name].id
  use_private_ip   = true

  type           = "label_selector"
  label_selector = each.value.label_selector

  lifecycle {
    replace_triggered_by = [
      # Can't reference a specific network, only count.index or each.key are supported here
      hcloud_load_balancer_network.ingress_pool
    ]
  }

  depends_on = [hcloud_load_balancer_network.ingress_pool]
}

resource "hcloud_load_balancer_service" "ingress_pool" {
  for_each = {
    for entry in flatten([
      for pool in local.ingress_load_balancer_pools : [
        for lb_index in range(pool.count) : [
          for protocol in ["http", "https"] : {
            key = "${var.cluster_name}-${pool.name}-${lb_index + 1}-${protocol}"
            value = {
              lb_name     = "${var.cluster_name}-${pool.name}-${lb_index + 1}"
              listen_port = protocol == "http" ? 80 : 443
              destination_port = (
                protocol == "http" ?
                var.ingress_service_node_port_http :
                var.ingress_service_node_port_https
              )
            }
          }
        ]
      ]
    ]) : entry.key => entry.value
  }

  load_balancer_id = hcloud_load_balancer.ingress_pool[each.value.lb_name].id
  listen_port      = each.value.listen_port
  destination_port = each.value.destination_port
  protocol         = "tcp"
  proxyprotocol    = true

  health_check {
    protocol = "tcp"
    port     = each.value.destination_port
    interval = var.ingress_load_balancer_health_check_interval
    timeout  = var.ingress_load_balancer_health_check_timeout
    retries  = var.ingress_load_balancer_health_check_retries
  }

  depends_on = [hcloud_load_balancer_target.ingress_pool]
}
