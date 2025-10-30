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
      user_data,
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
      user_data,
      ssh_keys
    ]
  }
}

locals {
  # IPv4 private (RFC1918)
  ipv4_private_pattern = "^(10\\.|192\\.168\\.|172\\.(1[6-9]|2\\d|3[0-1])\\.)"

  # IPv4 special or non-public
  # 0/8, 127/8, 169.254/16, 100.64/10, 192.0.0/24, 192.0.2/24, 192.88.99/24,
  # 198.18/15, 198.51.100/24, 203.0.113/24, 224/4 multicast, 240/4 reserved
  ipv4_special_pattern = "^(0\\.|127\\.|169\\.254\\.|100\\.(6[4-9]|[7-9]\\d|1[01]\\d|12[0-7])\\.|192\\.0\\.0\\.|192\\.0\\.2\\.|192\\.88\\.99\\.|198\\.(1[8-9])\\.|198\\.51\\.100\\.|203\\.0\\.113\\.|22[4-9]\\.|23\\d\\.|24\\d\\.|25[0-5]\\.)"

  # IPv6 private (ULA only: fc00::/7)
  ipv6_private_pattern = "^f[cd][0-9a-f]{2}:"

  # IPv6 non-public or special
  # ::, ::1, link-local fe80::/10 (fe80..febf), unique local fc00::/7, multicast ff00::/8,
  # documentation 2001:db8::/32, IPv4-mapped ::ffff:0:0/96
  ipv6_non_public_pattern = "^(::$|::1$|fe[89ab][0-9a-f]:|f[cd][0-9a-f]*:|ff[0-9a-f]*:|2001:db8:|::ffff:)"

  talos_discovery_cluster_autoscaler = {
    for m in jsondecode(data.external.talos_member.result.cluster_autoscaler) : m.spec.hostname => {
      nodepool = regex(local.cluster_autoscaler_hostname_pattern, m.spec.hostname)[0]

      private_ipv4_address = try(
        [
          for a in m.spec.addresses : a
          if can(cidrnetmask("${a}/32"))
          && can(regex(local.ipv4_private_pattern, a))
        ][0], null
      )
      public_ipv4_address = try(
        [
          for a in m.spec.addresses : a
          if can(cidrnetmask("${a}/32"))
          && !can(regex(local.ipv4_private_pattern, a))
          && !can(regex(local.ipv4_special_pattern, a))
        ][0], null
      )
      private_ipv6_address = try(
        [
          for a in m.spec.addresses : lower(a)
          if can(cidrsubnet("${a}/128", 0, 0))
          && can(regex(local.ipv6_private_pattern, lower(a)))
        ][0], null
      )
      public_ipv6_address = try(
        [
          for a in m.spec.addresses : lower(a)
          if can(cidrsubnet("${a}/128", 0, 0))
          && !can(regex(local.ipv6_non_public_pattern, lower(a)))
        ][0], null
      )
    }
  }
}

data "external" "talos_member" {
  program = [
    "sh", "-c", <<-EOT
      set -eu

      talosconfig=$(mktemp)
      trap 'rm -f "$talosconfig"' EXIT HUP INT TERM QUIT PIPE
      jq -r '.talosconfig' > "$talosconfig"

      if ${local.cluster_initialized}; then
        if talos_member_json=$(talosctl --talosconfig "$talosconfig" get member -n '${terraform_data.talos_access_data.output.talos_primary_node}' -o json); then
          printf '%s' "$talos_member_json" | jq -c -s '{
            control_plane: (
              map(select(.spec.machineType == "controlplane")) | tostring
            ),
            worker: (
              map(select(
                .spec.machineType == "worker"
                and (.spec.hostname | test("${local.cluster_autoscaler_hostname_pattern}") | not)
              )) | tostring
            ),
            cluster_autoscaler: (
              map(select(
                .spec.machineType == "worker"
                and (.spec.hostname | test("${local.cluster_autoscaler_hostname_pattern}"))
              )) | tostring
            )
          }'
        else
          printf '%s\n' "talosctl failed" >&2
          exit 1
        fi
      else
        printf '%s\n' '{"control_plane":"[]","cluster_autoscaler":"[]","worker":"[]"}'
      fi
    EOT
  ]

  query = {
    talosconfig = data.talos_client_configuration.this.talos_config
  }

  depends_on = [
    data.external.client_prerequisites_check,
    data.external.talosctl_version_check,
    data.talos_machine_configuration.control_plane,
    data.talos_machine_configuration.worker,
    data.talos_machine_configuration.cluster_autoscaler
  ]
}
