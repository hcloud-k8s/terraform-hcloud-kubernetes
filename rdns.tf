locals {
  rdns_cluster_domain_pattern = "/{{\\s*cluster-domain\\s*}}/"
  rdns_cluster_name_pattern   = "/{{\\s*cluster-name\\s*}}/"
  rdns_hostname_pattern       = "/{{\\s*hostname\\s*}}/"
  rdns_id_pattern             = "/{{\\s*id\\s*}}/"
  rdns_ip_labels_pattern      = "/{{\\s*ip-labels\\s*}}/"
  rdns_ip_type_pattern        = "/{{\\s*ip-type\\s*}}/"
  rdns_pool_pattern           = "/{{\\s*pool\\s*}}/"
  rdns_role_pattern           = "/{{\\s*role\\s*}}/"

  cluster_rdns_ipv4 = var.cluster_rdns_ipv4 != null ? var.cluster_rdns_ipv4 : var.cluster_rdns
  cluster_rdns_ipv6 = var.cluster_rdns_ipv6 != null ? var.cluster_rdns_ipv6 : var.cluster_rdns

  bare_metal_rdns_entry_values = {
    for entry in flatten([
      for server_name, server in local.bare_metal_servers : [
        for ip_type in concat(
          local.bare_metal_nodepools_map[server.nodepool].rdns_ipv4 != null ? ["ipv4"] : [],
          local.bare_metal_nodepools_map[server.nodepool].rdns_ipv6 != null && local.bare_metal_public_ipv6_enabled[server_name] ? ["ipv6"] : [],
          ) : {
          key = "${server.name}-${ip_type}"
          value = {
            ip_address = ip_type == "ipv4" ? local.bare_metal_server_public_network[server_name].server_ipv4 : local.bare_metal_public_ipv6_addresses[server_name]
            rdns = (
              ip_type == "ipv4" ?
              local.bare_metal_nodepools_map[server.nodepool].rdns_ipv4 :
              local.bare_metal_nodepools_map[server.nodepool].rdns_ipv6
            )
            hostname = server.name
            id       = tostring(server.number)
            ip_labels = (
              ip_type == "ipv4" ?
              join(".", reverse(split(".", local.bare_metal_server_public_network[server_name].server_ipv4))) :
              join(".", reverse(flatten([
                for part in split(":", replace(
                  local.bare_metal_public_ipv6_addresses[server_name], "::", ":${join(":",
                    slice(
                      [0, 0, 0, 0, 0, 0, 0, 0],
                      0, 8 - length(compact(split(":", local.bare_metal_public_ipv6_addresses[server_name])))
                    )
                  )}:"
                )) : [for char in split("", format("%04s", part)) : char]
              ])))
            )
            ip_type = ip_type
            pool    = server.nodepool
            role    = "worker"
          }
        }
      ]
    ]) : entry.key => entry.value
  }

  bare_metal_rdns_entries = {
    for key, entry in local.bare_metal_rdns_entry_values : key => merge(entry, {
      dns_ptr = replace(replace(replace(replace(replace(replace(replace(replace((entry.rdns
        ), local.rdns_cluster_domain_pattern, var.cluster_domain
        ), local.rdns_cluster_name_pattern, var.cluster_name
        ), local.rdns_hostname_pattern, entry.hostname
        ), local.rdns_id_pattern, entry.id
        ), local.rdns_ip_labels_pattern, entry.ip_labels
        ), local.rdns_ip_type_pattern, entry.ip_type
        ), local.rdns_pool_pattern, entry.pool
        ), local.rdns_role_pattern, entry.role
      )
    })
  }

  ingress_load_balancer_rdns_ipv4 = (
    var.ingress_load_balancer_rdns_ipv4 != null ? var.ingress_load_balancer_rdns_ipv4 :
    var.ingress_load_balancer_rdns != null ? var.ingress_load_balancer_rdns :
    local.cluster_rdns_ipv4
  )
  ingress_load_balancer_rdns_ipv6 = (
    var.ingress_load_balancer_rdns_ipv6 != null ? var.ingress_load_balancer_rdns_ipv6 :
    var.ingress_load_balancer_rdns != null ? var.ingress_load_balancer_rdns :
    local.cluster_rdns_ipv6
  )
}

resource "hcloud_rdns" "control_plane" {
  for_each = {
    for entry in flatten([
      for server in hcloud_server.control_plane : [
        for ip_type in concat(
          local.control_plane_nodepools_map[server.labels.nodepool].rdns_ipv4 != null ? ["ipv4"] : [],
          local.control_plane_nodepools_map[server.labels.nodepool].rdns_ipv6 != null ? ["ipv6"] : [],
          ) : {
          key = "${server.name}-${ip_type}"
          value = {
            ip_address = ip_type == "ipv4" ? server.ipv4_address : server.ipv6_address
            rdns = (
              ip_type == "ipv4" ?
              local.control_plane_nodepools_map[server.labels.nodepool].rdns_ipv4 :
              local.control_plane_nodepools_map[server.labels.nodepool].rdns_ipv6
            )
            hostname = server.name
            id       = server.id
            ip_labels = (
              ip_type == "ipv4" ?
              join(".", reverse(split(".", server.ipv4_address))) :
              join(".", reverse(flatten([
                for part in split(":", replace(
                  server.ipv6_address, "::", ":${join(":",
                    slice(
                      [0, 0, 0, 0, 0, 0, 0, 0],
                      0, 8 - length(compact(split(":", server.ipv6_address)))
                    )
                  )}:"
                )) : [for char in split("", format("%04s", part)) : char]
              ])))
            )
            ip_type = ip_type
            pool    = server.labels.nodepool
            role    = server.labels.role
          }
        }
      ]
    ]) : entry.key => entry.value
  }

  server_id  = each.value.id
  ip_address = each.value.ip_address
  dns_ptr = (
    replace(replace(replace(replace(replace(replace(replace(replace((each.value.rdns
      ), local.rdns_cluster_domain_pattern, var.cluster_domain
      ), local.rdns_cluster_name_pattern, var.cluster_name
      ), local.rdns_hostname_pattern, each.value.hostname
      ), local.rdns_id_pattern, each.value.id
      ), local.rdns_ip_labels_pattern, each.value.ip_labels
      ), local.rdns_ip_type_pattern, each.value.ip_type
      ), local.rdns_pool_pattern, each.value.pool
      ), local.rdns_role_pattern, each.value.role
    )
  )
}

resource "hcloud_rdns" "worker" {
  for_each = {
    for entry in flatten([
      for server in hcloud_server.worker : [
        for ip_type in concat(
          local.worker_nodepools_map[server.labels.nodepool].rdns_ipv4 != null ? ["ipv4"] : [],
          local.worker_nodepools_map[server.labels.nodepool].rdns_ipv6 != null ? ["ipv6"] : [],
          ) : {
          key = "${server.name}-${ip_type}"
          value = {
            ip_address = ip_type == "ipv4" ? server.ipv4_address : server.ipv6_address
            rdns = (
              ip_type == "ipv4" ?
              local.worker_nodepools_map[server.labels.nodepool].rdns_ipv4 :
              local.worker_nodepools_map[server.labels.nodepool].rdns_ipv6
            )
            hostname = server.name
            id       = server.id
            ip_labels = (
              ip_type == "ipv4" ?
              join(".", reverse(split(".", server.ipv4_address))) :
              join(".", reverse(flatten([
                for part in split(":", replace(
                  server.ipv6_address, "::", ":${join(":",
                    slice(
                      [0, 0, 0, 0, 0, 0, 0, 0],
                      0, 8 - length(compact(split(":", server.ipv6_address)))
                    )
                  )}:"
                )) : [for char in split("", format("%04s", part)) : char]
              ])))
            )
            ip_type = ip_type
            pool    = server.labels.nodepool
            role    = server.labels.role
          }
        }
      ]
    ]) : entry.key => entry.value
  }

  server_id  = each.value.id
  ip_address = each.value.ip_address
  dns_ptr = (
    replace(replace(replace(replace(replace(replace(replace(replace((each.value.rdns
      ), local.rdns_cluster_domain_pattern, var.cluster_domain
      ), local.rdns_cluster_name_pattern, var.cluster_name
      ), local.rdns_hostname_pattern, each.value.hostname
      ), local.rdns_id_pattern, each.value.id
      ), local.rdns_ip_labels_pattern, each.value.ip_labels
      ), local.rdns_ip_type_pattern, each.value.ip_type
      ), local.rdns_pool_pattern, each.value.pool
      ), local.rdns_role_pattern, each.value.role
    )
  )
}

resource "terraform_data" "bare_metal_rdns" {
  for_each = local.bare_metal_rdns_entries

  triggers_replace = {
    robot_password = var.hcloud_robot_password
    ip_address     = each.value.ip_address
    dns_ptr        = each.value.dns_ptr
  }

  input = {
    robot_api_url = var.hcloud_robot_api_url
    robot_user    = var.hcloud_robot_user
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Setting Robot rDNS for %s to %s\n' "${self.triggers_replace.ip_address}" "${self.triggers_replace.dns_ptr}"

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        --data-urlencode "ptr=${self.triggers_replace.dns_ptr}" \
        "${self.input.robot_api_url}/rdns/${self.triggers_replace.ip_address}" || true)

      case "$status" in
        200|201)
          ;;
        *)
          printf 'Unexpected Robot API status while setting rDNS for %s: %s\n' "${self.triggers_replace.ip_address}" "$status" >&2
          cat "$response_file" >&2
          exit 1
          ;;
      esac

      printf 'Robot rDNS set for %s\n' "${self.triggers_replace.ip_address}"
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.triggers_replace.robot_password)
    }
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Deleting Robot rDNS for %s\n' "${self.triggers_replace.ip_address}"

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        -X DELETE \
        "${self.input.robot_api_url}/rdns/${self.triggers_replace.ip_address}" || true)

      case "$status" in
        200|204|404)
          ;;
        *)
          printf 'Unexpected Robot API status while deleting rDNS for %s: %s\n' "${self.triggers_replace.ip_address}" "$status" >&2
          cat "$response_file" >&2
          exit 1
          ;;
      esac
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.triggers_replace.robot_password)
    }
  }
}

resource "hcloud_rdns" "ingress" {
  for_each = {
    for entry in flatten([
      for lb in hcloud_load_balancer.ingress : [
        for ip_type in concat(
          local.ingress_load_balancer_rdns_ipv4 != null ? ["ipv4"] : [],
          local.ingress_load_balancer_rdns_ipv6 != null ? ["ipv6"] : [],
          ) : {
          key = "${lb.name}-${ip_type}"
          value = {
            ip_address = ip_type == "ipv4" ? lb.ipv4 : lb.ipv6
            rdns = (
              ip_type == "ipv4" ?
              local.ingress_load_balancer_rdns_ipv4 :
              local.ingress_load_balancer_rdns_ipv6
            )
            hostname = lb.name
            id       = lb.id
            ip_labels = (
              ip_type == "ipv4" ?
              join(".", reverse(split(".", lb.ipv4))) :
              join(".", reverse(flatten([
                for part in split(":", replace(
                  lb.ipv6, "::", ":${join(":",
                    slice(
                      [0, 0, 0, 0, 0, 0, 0, 0],
                      0, 8 - length(compact(split(":", lb.ipv6)))
                    )
                  )}:"
                )) : [for char in split("", format("%04s", part)) : char]
              ])))
            )
            ip_type = ip_type
            pool    = "ingress"
            role    = lb.labels.role
          }
        }
      ]
    ]) : entry.key => entry.value
  }

  load_balancer_id = each.value.id
  ip_address       = each.value.ip_address
  dns_ptr = (
    replace(replace(replace(replace(replace(replace(replace(replace((each.value.rdns
      ), local.rdns_cluster_domain_pattern, var.cluster_domain
      ), local.rdns_cluster_name_pattern, var.cluster_name
      ), local.rdns_hostname_pattern, each.value.hostname
      ), local.rdns_id_pattern, each.value.id
      ), local.rdns_ip_labels_pattern, each.value.ip_labels
      ), local.rdns_ip_type_pattern, each.value.ip_type
      ), local.rdns_pool_pattern, each.value.pool
      ), local.rdns_role_pattern, each.value.role
    )
  )
}

resource "hcloud_rdns" "ingress_pool" {
  for_each = {
    for entry in flatten([
      for lb in hcloud_load_balancer.ingress_pool : [
        for ip_type in concat(
          local.ingress_load_balancer_pools_map[lb.labels.pool].rdns_ipv4 != null ? ["ipv4"] : [],
          local.ingress_load_balancer_pools_map[lb.labels.pool].rdns_ipv6 != null ? ["ipv6"] : [],
          ) : {
          key = "${lb.name}-${ip_type}"
          value = {
            ip_address = ip_type == "ipv4" ? lb.ipv4 : lb.ipv6
            rdns = (
              ip_type == "ipv4" ?
              local.ingress_load_balancer_pools_map[lb.labels.pool].rdns_ipv4 :
              local.ingress_load_balancer_pools_map[lb.labels.pool].rdns_ipv6
            )
            hostname = lb.name
            id       = lb.id
            ip_labels = (
              ip_type == "ipv4" ?
              join(".", reverse(split(".", lb.ipv4))) :
              join(".", reverse(flatten([
                for part in split(":", replace(
                  lb.ipv6, "::", ":${join(":",
                    slice(
                      [0, 0, 0, 0, 0, 0, 0, 0],
                      0, 8 - length(compact(split(":", lb.ipv6)))
                    )
                  )}:"
                )) : [for char in split("", format("%04s", part)) : char]
              ])))
            )
            ip_type = ip_type
            pool    = lb.labels.pool
            role    = lb.labels.role
          }
        }
      ]
    ]) : entry.key => entry.value
  }

  load_balancer_id = each.value.id
  ip_address       = each.value.ip_address
  dns_ptr = (
    replace(replace(replace(replace(replace(replace(replace(replace((each.value.rdns
      ), local.rdns_cluster_domain_pattern, var.cluster_domain
      ), local.rdns_cluster_name_pattern, var.cluster_name
      ), local.rdns_hostname_pattern, each.value.hostname
      ), local.rdns_id_pattern, each.value.id
      ), local.rdns_ip_labels_pattern, each.value.ip_labels
      ), local.rdns_ip_type_pattern, each.value.ip_type
      ), local.rdns_pool_pattern, each.value.pool
      ), local.rdns_role_pattern, each.value.role
    )
  )
}
