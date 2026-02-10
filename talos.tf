locals {
  # Talos Version
  talos_version_parts = regex("^v?(?P<major>[0-9]+)\\.(?P<minor>[0-9]+)\\.(?P<patch>[0-9]+)", var.talos_version)
  talos_version_major = local.talos_version_parts.major
  talos_version_minor = local.talos_version_parts.minor
  talos_version_patch = local.talos_version_parts.patch

  # Talos Nodes
  talos_primary_node_name         = sort(keys(hcloud_server.control_plane))[0]
  talos_primary_node_private_ipv4 = tolist(hcloud_server.control_plane[local.talos_primary_node_name].network)[0].ip
  talos_primary_node_public_ipv4  = hcloud_server.control_plane[local.talos_primary_node_name].ipv4_address
  talos_primary_node_public_ipv6  = hcloud_server.control_plane[local.talos_primary_node_name].ipv6_address

  # Talos API
  talos_api_port = 50000
  talos_primary_endpoint = var.cluster_access == "private" ? local.talos_primary_node_private_ipv4 : coalesce(
    local.talos_primary_node_public_ipv4, local.talos_primary_node_public_ipv6
  )
  talos_endpoints = compact(
    var.cluster_access == "private" ? local.control_plane_private_ipv4_list : concat(
      local.network_public_ipv4_enabled ? local.control_plane_public_ipv4_list : [],
      local.network_public_ipv6_enabled ? local.control_plane_public_ipv6_list : []
    )
  )

  # Kubernetes API
  kube_api_private_ipv4 = (
    var.kube_api_load_balancer_enabled ? local.kube_api_load_balancer_private_ipv4 :
    var.control_plane_private_vip_ipv4_enabled ? local.control_plane_private_vip_ipv4 :
    local.talos_primary_node_private_ipv4
  )

  kube_api_port = 6443
  kube_api_host = coalesce(
    var.kube_api_hostname,
    var.cluster_access == "private" ? local.kube_api_private_ipv4 : null,
    (
      var.kube_api_load_balancer_enabled && local.kube_api_load_balancer_public_network_enabled ?
      coalesce(local.kube_api_load_balancer_public_ipv4, local.kube_api_load_balancer_public_ipv6) : null
    ),
    var.control_plane_public_vip_ipv4_enabled ? local.control_plane_public_vip_ipv4 : null,
    local.talos_primary_node_public_ipv4,
    local.talos_primary_node_public_ipv6
  )

  kube_api_url_internal = "https://${local.kube_api_private_ipv4}:${local.kube_api_port}"
  kube_api_url_external = "https://${local.kube_api_host}:${local.kube_api_port}"

  # KubePrism
  kube_prism_host = "127.0.0.1"
  kube_prism_port = 7445

  # Talos Control
  talosctl_commands = templatefile("${path.module}/templates/talosctl_commands.sh.tftpl", {
    talos_upgrade_debug       = var.talos_upgrade_debug
    talos_upgrade_force       = var.talos_upgrade_force
    talos_upgrade_insecure    = var.talos_upgrade_insecure
    talos_upgrade_stage       = var.talos_upgrade_stage
    talos_upgrade_reboot_mode = var.talos_upgrade_reboot_mode
    talos_installer_image_url = local.talos_installer_image_url
    talosctl_retries          = var.talosctl_retries
    healthcheck_enabled       = var.cluster_healthcheck_enabled
    talos_primary_node        = local.talos_primary_node_private_ipv4
    kube_api_url              = local.kube_api_url_external
    kubernetes_version        = var.kubernetes_version
    control_plane_nodes       = local.control_plane_private_ipv4_list
    worker_nodes = concat(
      local.worker_private_ipv4_list,
      local.cluster_autoscaler_private_ipv4_list
    )
  })

  # Cluster Status
  cluster_initialized = length(data.hcloud_certificates.state.certificates) > 0
}

data "hcloud_certificates" "state" {
  with_selector = join(",",
    [
      "cluster=${var.cluster_name}",
      "state=initialized"
    ]
  )
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version

  lifecycle {
    prevent_destroy = true
  }
}

resource "terraform_data" "upgrade_control_plane" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Control Plane Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.control_plane_private_ipv4_list
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Control Plane Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Control Plane Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.control_plane,
    data.talos_client_configuration.this
  ]
}

resource "terraform_data" "upgrade_worker" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Worker Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.worker_private_ipv4_list
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Worker Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Worker Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.worker,
    terraform_data.upgrade_control_plane
  ]
}

resource "terraform_data" "upgrade_cluster_autoscaler" {
  count = var.cluster_autoscaler_discovery_enabled ? 1 : 0

  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Cluster Autoscaler Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.cluster_autoscaler_private_ipv4_list
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Cluster Autoscaler Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Cluster Autoscaler Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.cluster_autoscaler,
    terraform_data.upgrade_control_plane,
    terraform_data.upgrade_worker
  ]
}

resource "terraform_data" "upgrade_kubernetes" {
  triggers_replace = [var.kubernetes_version]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n",
      [
        "set -eu",
        local.cluster_initialized ? join("\n",
          [
            local.talosctl_commands,
            "printf '%s\\n' \"Start upgrading Kubernetes\"",
            templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
            "printf '%s\\n' \"Kubernetes upgraded successfully\"",
          ]
        ) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes upgrade\"",
    ])

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    terraform_data.upgrade_control_plane,
    terraform_data.upgrade_worker,
    terraform_data.upgrade_cluster_autoscaler
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = { for control_plane in hcloud_server.control_plane : control_plane.name => control_plane }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  endpoint                    = var.cluster_access == "private" ? tolist(each.value.network)[0].ip : coalesce(each.value.ipv4_address, each.value.ipv6_address)
  node                        = tolist(each.value.network)[0].ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = true
    reboot   = false
  }

  depends_on = [
    hcloud_load_balancer_service.kube_api,
    terraform_data.upgrade_kubernetes
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = { for worker in hcloud_server.worker : worker.name => worker }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  endpoint                    = var.cluster_access == "private" ? tolist(each.value.network)[0].ip : coalesce(each.value.ipv4_address, each.value.ipv6_address)
  node                        = tolist(each.value.network)[0].ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = true
    reboot   = false
  }

  depends_on = [
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.control_plane
  ]
}

resource "terraform_data" "talos_machine_configuration_apply_cluster_autoscaler" {
  count = var.cluster_autoscaler_discovery_enabled ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(jsonencode({
      for k, r in data.talos_machine_configuration.cluster_autoscaler :
      k => r.machine_configuration
    })))
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n", [
      "set -eu",
      local.talosctl_commands,
      templatefile("${path.module}/templates/talos_apply_config.sh.tftpl", {
        target_nodes = local.cluster_autoscaler_private_ipv4_list
      })
    ])

    environment = merge(
      { TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config) },
      {
        for server in local.talos_discovery_cluster_autoscaler :
        "TALOS_MC_${replace(server.private_ipv4_address, ".", "_")}" =>
        nonsensitive(data.talos_machine_configuration.cluster_autoscaler[server.nodepool].machine_configuration)
      }
    )
  }

  depends_on = [
    data.external.talosctl_version_check,
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.talos_primary_endpoint
  node                 = local.talos_primary_node_private_ipv4

  depends_on = [
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
    terraform_data.talos_machine_configuration_apply_cluster_autoscaler
  ]
}

resource "terraform_data" "synchronize_manifests" {
  triggers_replace = [
    nonsensitive(sha1(jsonencode(local.talos_inline_manifests))),
    nonsensitive(sha1(jsonencode(local.talos_remote_manifests))),
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n",
      [
        "set -eu",
        local.cluster_initialized ? join("\n",
          [
            local.talosctl_commands,
            "printf '%s\\n' \"Start synchronizing Kubernetes manifests\"",
            templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
            "printf '%s\\n' \"Kubernetes manifests synchronized successfully\"",
          ]
        ) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes manifest synchronization\"",
      ]
    )

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
    terraform_data.talos_machine_configuration_apply_cluster_autoscaler
  ]
}

resource "tls_private_key" "state" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "state" {
  private_key_pem = tls_private_key.state.private_key_pem

  subject { common_name = var.cluster_name }
  allowed_uses          = ["server_auth"]
  validity_period_hours = 876600
}

resource "hcloud_uploaded_certificate" "state" {
  name = "${var.cluster_name}-state"

  private_key = tls_private_key.state.private_key_pem
  certificate = tls_self_signed_cert.state.cert_pem

  labels = {
    cluster = var.cluster_name
    state   = "initialized"
  }

  depends_on = [terraform_data.synchronize_manifests]
}

resource "terraform_data" "talos_access_data" {
  input = {
    kube_api_source     = local.firewall_kube_api_sources
    talos_api_source    = local.firewall_talos_api_sources
    talos_primary_node  = local.talos_primary_node_private_ipv4
    endpoints           = local.talos_endpoints
    control_plane_nodes = local.control_plane_private_ipv4_list
    worker_nodes        = local.worker_private_ipv4_list
    kube_api_url        = local.kube_api_url_external
  }
}

data "http" "kube_api_health" {
  count = var.cluster_healthcheck_enabled ? 1 : 0

  url      = "${terraform_data.talos_access_data.output.kube_api_url}/version"
  insecure = true

  retry {
    attempts     = 60
    min_delay_ms = 5000
    max_delay_ms = 5000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 401
      error_message = "Status code invalid"
    }
  }

  depends_on = [terraform_data.synchronize_manifests]
}

data "talos_cluster_health" "this" {
  count = var.cluster_healthcheck_enabled && (var.cluster_access == "private") ? 1 : 0

  client_configuration   = talos_machine_secrets.this.client_configuration
  endpoints              = terraform_data.talos_access_data.output.endpoints
  control_plane_nodes    = terraform_data.talos_access_data.output.control_plane_nodes
  worker_nodes           = terraform_data.talos_access_data.output.worker_nodes
  skip_kubernetes_checks = false

  depends_on = [data.http.kube_api_health]
}
