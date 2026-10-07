locals {
  hcloud_load_balancer_location = coalesce(
    var.hcloud_ccm_load_balancers_location,
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
