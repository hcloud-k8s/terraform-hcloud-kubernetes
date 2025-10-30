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
  talosctl_upgrade_command = join(" ",
    [
      "talosctl upgrade",
      "--talosconfig \"$talosconfig\"",
      "--nodes \"$host\"",
      "--image '${local.talos_installer_image_url}'"
    ]
  )
  talosctl_upgrade_k8s_command = join(" ",
    [
      "talosctl upgrade-k8s",
      "--talosconfig \"$talosconfig\"",
      "--nodes '${local.talos_primary_node_private_ipv4}'",
      "--endpoint '${local.kube_api_url_external}'",
      "--to '${var.kubernetes_version}'",
      "--with-docs=false",
      "--with-examples=false"
    ]
  )
  talosctl_apply_config_command = join(" ",
    [
      "talosctl apply-config",
      "--talosconfig \"$talosconfig\"",
      "--nodes \"$host\"",
      "--file \"$machine_config\""
    ]
  )
  talosctl_health_check_command = join(" ",
    [
      "talosctl health",
      "--talosconfig \"$talosconfig\"",
      "--server=true",
      "--control-plane-nodes '${join(",", local.control_plane_private_ipv4_list)}'",
      "--worker-nodes '${join(",", concat(local.worker_private_ipv4_list, local.cluster_autoscaler_private_ipv4_list))}'"
    ]
  )
  talosctl_retry_snippet = join(" ",
    [
      "[ \"$retry\" -gt ${var.talosctl_retry_count} ] && exit 1 ||",
      "{ printf '%s\n' \"Retry $retry/${var.talosctl_retry_count} ...\"; retry=$((retry + 1)); sleep 10; }"
    ]
  )
  talosctl_get_version_command = join(" ",
    [
      "talosctl get version",
      "--talosconfig \"$talosconfig\"",
      "--nodes \"$host\"",
      "--output jsonpath='{.spec.version}'",
      "2>/dev/null || true"
    ]
  )
  talosctl_get_schematic_command = join(" ",
    [
      "talosctl get extensions",
      "--talosconfig \"$talosconfig\"",
      "--nodes \"$host\"",
      "--output json",
      "| jq -r 'select(.spec.metadata.name==\"schematic\") | .spec.metadata.version'",
      "2>/dev/null || true"
    ]
  )
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

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      if ${local.cluster_initialized}; then
        printf '%s\n' "Start upgrading Control Plane Nodes"

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.control_plane_private_ipv4_list[0]}'; do
          ${local.talosctl_retry_snippet}
        done

        set -- ${join(" ", local.control_plane_private_ipv4_list)}
        for host in "$@"; do
          printf '%s\n' "Checking node $host ..."

          retry=1
          while true; do
            current_version=$(${local.talosctl_get_version_command})
            current_schematic=$(${local.talosctl_get_schematic_command})
            if [ "$current_version" = "${var.talos_version}" ] && [ "$current_schematic" = "${local.talos_schematic_id}" ]; then
              if [ "$retry" -gt 1 ]; then
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Waiting for cluster to stabilize ..."
                sleep 5

                retry=1
                while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                  ${local.talosctl_retry_snippet}
                done
                printf '%s\n' "Node $host upgraded successfully"
              else
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Skipping upgrade ..."
              fi
              break
            elif [ -n "$current_version" ] && [ -n "$current_schematic" ]; then
              printf '%s\n' "Node $host is currently at Talos $current_version ($current_schematic)"
            else
              printf '%s\n' "Could not determine current Talos version or schematic for node $host"
            fi

            printf '%s\n' "Upgrading node $host to Talos ${var.talos_version} (${local.talos_schematic_id}) ..."
            if ${local.talosctl_upgrade_command}; then
              printf '%s\n' "Upgrade successfully completed for node $host"
              sleep 5

              retry=1
              while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                ${local.talosctl_retry_snippet}
              done

              printf '%s\n' "Node $host upgraded successfully"
              break
            fi
            ${local.talosctl_retry_snippet}
          done
        done
        printf '%s\n' "Control Plane Nodes upgraded successfully"
      else
        printf '%s\n' "Cluster not initialized, skipping Control Plane Node upgrade"
      fi
    EOT

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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      if ${local.cluster_initialized}; then
        printf '%s\n' "Start upgrading Worker Nodes"

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        set -- ${join(" ", local.worker_private_ipv4_list)}
        for host in "$@"; do
          printf '%s\n' "Checking node $host ..."

          retry=1
          while true; do
            current_version=$(${local.talosctl_get_version_command})
            current_schematic=$(${local.talosctl_get_schematic_command})
            if [ "$current_version" = "${var.talos_version}" ] && [ "$current_schematic" = "${local.talos_schematic_id}" ]; then
              if [ "$retry" -gt 1 ]; then
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Waiting for cluster to stabilize ..."
                sleep 5

                retry=1
                while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                  ${local.talosctl_retry_snippet}
                done
                printf '%s\n' "Node $host upgraded successfully"
              else
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Skipping upgrade ..."
              fi
              break
            elif [ -n "$current_version" ] && [ -n "$current_schematic" ]; then
              printf '%s\n' "Node $host is currently at Talos $current_version ($current_schematic)"
            else
              printf '%s\n' "Could not determine current Talos version or schematic for node $host"
            fi

            printf '%s\n' "Upgrading node $host to Talos ${var.talos_version} (${local.talos_schematic_id}) ..."
            if ${local.talosctl_upgrade_command}; then
              printf '%s\n' "Upgrade successfully completed for node $host"
              sleep 5

              retry=1
              while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                ${local.talosctl_retry_snippet}
              done

              printf '%s\n' "Node $host upgraded successfully"
              break
            fi
            ${local.talosctl_retry_snippet}
          done
        done
        printf '%s\n' "Worker Nodes upgraded successfully"
      else
        printf '%s\n' "Cluster not initialized, skipping Worker Node upgrade"
      fi
    EOT

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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      if ${local.cluster_initialized}; then
        printf '%s\n' "Start upgrading Cluster Autoscaler Nodes"

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        set -- ${join(" ", local.cluster_autoscaler_private_ipv4_list)}
        for host in "$@"; do
          printf '%s\n' "Checking node $host ..."

          retry=1
          while true; do
            current_version=$(${local.talosctl_get_version_command})
            current_schematic=$(${local.talosctl_get_schematic_command})
            if [ "$current_version" = "${var.talos_version}" ] && [ "$current_schematic" = "${local.talos_schematic_id}" ]; then
              if [ "$retry" -gt 1 ]; then
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Waiting for cluster to stabilize ..."
                sleep 5

                retry=1
                while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                  ${local.talosctl_retry_snippet}
                done
                printf '%s\n' "Node $host upgraded successfully"
              else
                printf '%s\n' "Node $host is already at Talos $current_version ($current_schematic). Skipping upgrade ..."
              fi
              break
            elif [ -n "$current_version" ] && [ -n "$current_schematic" ]; then
              printf '%s\n' "Node $host is currently at Talos $current_version ($current_schematic)"
            else
              printf '%s\n' "Could not determine current Talos version or schematic for node $host"
            fi

            printf '%s\n' "Upgrading node $host to Talos ${var.talos_version} (${local.talos_schematic_id}) ..."
            if ${local.talosctl_upgrade_command}; then
              printf '%s\n' "Upgrade successfully completed for node $host"
              sleep 5

              retry=1
              while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
                ${local.talosctl_retry_snippet}
              done

              printf '%s\n' "Node $host upgraded successfully"
              break
            fi
            ${local.talosctl_retry_snippet}
          done
        done
        printf '%s\n' "Cluster Autoscaler Nodes upgraded successfully"
      else
        printf '%s\n' "Cluster not initialized, skipping Cluster Autoscaler Node upgrade"
      fi
    EOT

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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      if ${local.cluster_initialized}; then
        printf '%s\n' "Start upgrading Kubernetes"

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        retry=1
        while ! ${local.talosctl_upgrade_k8s_command}; do
          ${local.talosctl_retry_snippet}
        done
        sleep 5

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        printf '%s\n' "Kubernetes upgraded successfully"
      else
        printf '%s\n' "Cluster not initialized, skipping Kubernetes upgrade"
      fi
    EOT

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
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      set -- ${join(" ", local.cluster_autoscaler_private_ipv4_list)}
      for host in "$@"; do
        (
          set -eu
          
          machine_config=$(mktemp)
          trap 'rm -f "$machine_config"' EXIT HUP INT TERM QUIT PIPE

          printf '%s\n' "Applying machine configuration to Cluster Autoscaler Node: $host"
          envname="TALOS_MC_$(printf '%s' "$host" | tr . _)"
          eval "machine_config_value=\$${$envname}"
          printf '%s' "$machine_config_value" > "$machine_config"

          retry=1
          while ! ${local.talosctl_apply_config_command}; do
            ${local.talosctl_retry_snippet}
          done
        )
      done
    EOT

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
    var.talos_ccm_version,
    var.prometheus_operator_crds_version
  ]

  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      printf '%s' "$TALOSCONFIG" > "$talosconfig"

      if ${local.cluster_initialized}; then
        printf '%s\n' "Start synchronizing manifests"
        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        retry=1
        while ! ${local.talosctl_upgrade_k8s_command}; do
          ${local.talosctl_retry_snippet}
        done
        sleep 5

        retry=1
        while ${var.cluster_healthcheck_enabled} && ! ${local.talosctl_health_check_command} -n '${local.talos_primary_node_private_ipv4}'; do
          ${local.talosctl_retry_snippet}
        done

        printf '%s\n' "Manifests synchronized successfully"
      else
        printf '%s\n' "Cluster not initialized, skipping manifest synchronization"
      fi
    EOT

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
