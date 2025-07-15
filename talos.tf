locals {
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

  # Cluster Health
  talos_healthcheck_enabled = var.cluster_healthcheck_enabled && local.talos_discovery_enabled

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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig_tmp=$(mktemp)
      trap '{ rm -f "$talosconfig_tmp"; }' EXIT
      printf '%s' "$TALOSCONFIG_CONTENT" > "$talosconfig_tmp"

      if ${local.cluster_initialized}; then
        echo "Start upgrading control plane nodes"
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        set -- ${join(" ", local.control_plane_private_ipv4_list)}
        for host in "$@"; do
          talosctl --talosconfig "$talosconfig_tmp" upgrade -n "$host" --preserve --image '${local.talos_installer_image_url}'
          ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n "$host"
        done
        echo "Control plane nodes upgraded successfully"
      else
        echo "Cluster not initialized, skipping control plane node upgrade"
      fi
    EOT
    environment = {
      TALOSCONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig_tmp=$(mktemp)
      trap '{ rm -f "$talosconfig_tmp"; }' EXIT
      printf '%s' "$TALOSCONFIG_CONTENT" > "$talosconfig_tmp"

      if ${local.cluster_initialized}; then
        echo "Start upgrading worker nodes"
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        set -- ${join(" ", local.worker_private_ipv4_list)}
        for host in "$@"; do
          talosctl --talosconfig "$talosconfig_tmp" upgrade -n "$host" --preserve --image '${local.talos_installer_image_url}'
          ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        done
        echo "Worker nodes upgraded successfully"
      else
        echo "Cluster not initialized, skipping worker node upgrade"
      fi
    EOT
    environment = {
      TALOSCONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.talos_machine_configuration.worker,
    terraform_data.upgrade_control_plane
  ]
}

resource "terraform_data" "upgrade_kubernetes" {
  triggers_replace = [var.kubernetes_version]

  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig_tmp=$(mktemp)
      trap '{ rm -f "$talosconfig_tmp"; }' EXIT
      printf '%s' "$TALOSCONFIG_CONTENT" > "$talosconfig_tmp"

      if ${local.cluster_initialized}; then
        echo "Start upgrading Kubernetes"
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        talosctl --talosconfig "$talosconfig_tmp" upgrade-k8s -n '${local.talos_primary_node_private_ipv4}' --endpoint '${local.kube_api_url_external}' --to '${var.kubernetes_version}'
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        echo "Kubernetes upgraded successfully"
      else
        echo "Cluster not initialized, skipping Kubernetes upgrade"
      fi
    EOT
    environment = {
      TALOSCONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    terraform_data.upgrade_control_plane,
    terraform_data.upgrade_worker
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

resource "talos_machine_configuration_apply" "worker_extend" {
  for_each = { for worker in hcloud_server.worker_extend : worker.name => worker }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_extend[each.key].machine_configuration
  endpoint                    = var.cluster_access == "private" ? tolist(each.value.network)[0].ip : coalesce(each.value.ipv4_address, each.value.ipv6_address)
  node                        = tolist(each.value.network)[0].ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = true
    reboot   = false
  }

  # depends_on = [
  #   terraform_data.upgrade_kubernetes,
  #   talos_machine_configuration_apply.control_plane
  # ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.talos_primary_endpoint
  node                 = local.talos_primary_node_private_ipv4

  depends_on = [
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker
  ]
}

resource "terraform_data" "synchronize_manifests" {
  triggers_replace = [
    sha1(jsonencode(local.talos_inline_manifests)),
    var.talos_ccm_version,
    var.prometheus_operator_crds_version
  ]

  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig_tmp=$(mktemp)
      trap '{ rm -f "$talosconfig_tmp"; }' EXIT
      printf '%s' "$TALOSCONFIG_CONTENT" > "$talosconfig_tmp"

      if ${local.cluster_initialized}; then
        echo "Start synchronizing manifests"
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        talosctl --talosconfig "$talosconfig_tmp" upgrade-k8s -n '${local.talos_primary_node_private_ipv4}' --endpoint '${local.kube_api_url_external}' --to '${var.kubernetes_version}'
        ${local.talos_healthcheck_enabled} && talosctl --talosconfig "$talosconfig_tmp" health --server -n '${local.talos_primary_node_private_ipv4}'
        echo "Manifests synchronized successfully"
      else
        echo "Cluster not initialized, skipping manifest synchronization"
      fi
    EOT
    environment = {
      TALOSCONFIG_CONTENT = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [talos_machine_bootstrap.this]
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

resource "terraform_data" "talos_health_data" {
  input = {
    current_ip          = local.current_ip
    endpoints           = local.talos_endpoints
    control_plane_nodes = local.control_plane_private_ipv4_list
    worker_nodes        = local.worker_private_ipv4_list
    kube_api_url        = local.kube_api_url_external
  }
}

data "http" "kube_api_health" {
  count = var.cluster_healthcheck_enabled ? 1 : 0

  url      = "${terraform_data.talos_health_data.output.kube_api_url}/version"
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
  endpoints              = terraform_data.talos_health_data.output.endpoints
  control_plane_nodes    = terraform_data.talos_health_data.output.control_plane_nodes
  worker_nodes           = terraform_data.talos_health_data.output.worker_nodes
  skip_kubernetes_checks = false

  depends_on = [data.http.kube_api_health]
}

