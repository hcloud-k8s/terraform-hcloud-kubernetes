locals {
  # Bare Metal Network Config
  bare_metal_vswitch_link_name             = "${local.talos_public_link_name}.${local.hcloud_vswitch_vlan_id}"
  bare_metal_vswitch_ipv4_cidr_prefix_size = split("/", local.network_bare_metal_shared_ipv4_cidr)[1]
  bare_metal_vswitch_ipv4_netmask          = cidrnetmask(local.network_bare_metal_shared_ipv4_cidr)
  bare_metal_vswitch_ipv4_gateway          = cidrhost(local.network_bare_metal_shared_ipv4_cidr, 1)
  bare_metal_extra_routes = [
    for route in local.talos_extra_routes : merge(route, {
      gateway = local.bare_metal_vswitch_ipv4_gateway
    })
  ]

  bare_metal_public_ipv6_enabled = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => local.network_public_ipv6_enabled && local.bare_metal_server_public_network[server_name].server_ipv6_net != ""
  }

  bare_metal_public_ipv6_addresses = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => local.bare_metal_public_ipv6_enabled[server_name] ? cidrhost(
      format("%s/64", local.bare_metal_server_public_network[server_name].server_ipv6_net),
      1
    ) : null
  }

  bare_metal_talos_config_patches = {
    for server_name, server in local.bare_metal_servers : server_name => [
      {
        apiVersion = "v1alpha1"
        kind       = "LinkConfig"
        name       = local.talos_public_link_name
        up         = true
        addresses = concat(
          local.network_public_ipv4_enabled ? [
            {
              address = "${local.bare_metal_server_public_network[server_name].server_ipv4}/${local.bare_metal_server_public_network[server_name].server_ipv4_mask}"
            }
          ] : [],
          local.bare_metal_public_ipv6_enabled[server_name] ? [
            {
              address = "${local.bare_metal_public_ipv6_addresses[server_name]}/64"
            }
          ] : []
        )
        routes = concat(
          local.network_public_ipv4_enabled ? [
            {
              gateway = local.bare_metal_server_public_network[server_name].server_ipv4_gateway
            }
          ] : [],
          local.bare_metal_public_ipv6_enabled[server_name] ? [
            {
              gateway = "fe80::1"
            }
          ] : []
        )
      },
      {
        apiVersion = "v1alpha1"
        kind       = "VLANConfig"
        name       = local.bare_metal_vswitch_link_name
        parent     = local.talos_public_link_name
        vlanID     = local.hcloud_vswitch_vlan_id
        mtu        = 1400
        addresses = [
          {
            address = "${server.private_ipv4}/${local.bare_metal_vswitch_ipv4_cidr_prefix_size}"
          }
        ]
        routes = concat(
          [
            {
              destination = local.network_ipv4_cidr
              gateway     = local.bare_metal_vswitch_ipv4_gateway
              metric      = 512
            }
          ],
          local.bare_metal_extra_routes
        )
      },
      {
        machine = {
          nodeLabels = merge(
            local.bare_metal_nodepools_map[server.nodepool].labels,
            {
              "nodeid"                             = tostring(server.number),
              "instance.hetzner.cloud/provided-by" = "robot"
            }
          )
          nodeAnnotations = local.bare_metal_nodepools_map[server.nodepool].annotations
          kubelet = {
            extraArgs = {
              "provider-id" = "hrobot://${server.number}"
            }
            extraConfig = merge(
              {
                registerWithTaints = local.bare_metal_nodepools_map[server.nodepool].taints
                systemReserved = {
                  cpu               = "100m"
                  memory            = "300Mi"
                  ephemeral-storage = "1Gi"
                }
                kubeReserved = {
                  cpu               = "100m"
                  memory            = "350Mi"
                  ephemeral-storage = "1Gi"
                }
              },
              var.kubernetes_kubelet_extra_config
            )
          }
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = server.name
        auto       = "off"
      }
    ]
  }
}

data "talos_machine_configuration" "bare_metal" {
  for_each = local.bare_metal_servers

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_common_config_patches : yamlencode(patch)],
    [for patch in local.bare_metal_talos_config_patches[each.key] : yamlencode(patch)],
    [for patch in var.bare_metal_config_patches : yamlencode(patch)]
  )
}
