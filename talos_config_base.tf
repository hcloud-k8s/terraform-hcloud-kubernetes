locals {
  # Talos and Kubernetes Certificates
  talos_certificate_san = sort(
    distinct(
      compact(
        concat(
          # Virtual IPs
          var.control_plane_public_vip_ipv4_enabled ? [local.control_plane_public_vip_ipv4] : [],
          [local.control_plane_private_vip_ipv4],
          # Load Balancer IPs
          [
            local.kube_api_load_balancer_private_ipv4,
            local.kube_api_load_balancer_public_ipv4,
            local.kube_api_load_balancer_public_ipv6
          ],
          # Control Plane Node IPs
          local.control_plane_private_ipv4_list,
          local.control_plane_public_ipv4_list,
          local.control_plane_public_ipv6_list,
          # Other Addresses
          [var.kube_api_hostname],
          ["127.0.0.1", "::1", "localhost"],
        )
      )
    )
  )

  # Interface Configuration
  talos_public_interface_enabled = var.talos_public_ipv4_enabled || var.talos_public_ipv6_enabled
  talos_public_link_name         = "eth0"
  talos_private_link_name        = local.talos_public_interface_enabled ? "eth1" : "eth0"

  # Routes
  talos_extra_routes = [for cidr in var.talos_extra_routes : {
    destination = cidr
    gateway     = local.network_ipv4_gateway
    metric      = 512
  }]

  # DNS Configuration
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

  # Disk Encryption Configuration
  talos_system_disk_encryption = merge(
    var.talos_state_partition_encryption_enabled ? {
      state = {
        provider = "luks2"
        options  = ["no_read_workqueue", "no_write_workqueue"]
        keys = [{
          nodeID = {}
          slot   = 0
        }]
      }
    } : {},
    var.talos_ephemeral_partition_encryption_enabled ? {
      ephemeral = {
        provider = "luks2"
        options  = ["no_read_workqueue", "no_write_workqueue"]
        keys = [{
          nodeID = {}
          slot   = 0
        }]
      }
    } : {}
  )

  # Kubelet extra mounts
  talos_kubelet_extra_mounts = concat(
    var.longhorn_enabled ? [
      {
        source      = "/var/lib/longhorn"
        destination = "/var/lib/longhorn"
        type        = "bind"
        options     = ["bind", "rshared", "rw"]
      }
    ] : [],
    [
      for mount in var.talos_kubelet_extra_mounts : {
        source      = mount.source
        destination = coalesce(mount.destination, mount.source)
        type        = mount.type
        options     = mount.options
      }
    ]
  )

  # Talos Discovery
  talos_discovery_enabled = var.talos_discovery_kubernetes_enabled || var.talos_discovery_service_enabled

  talos_discovery = {
    enabled = local.talos_discovery_enabled
    registries = {
      kubernetes = { disabled = !var.talos_discovery_kubernetes_enabled }
      service    = { disabled = !var.talos_discovery_service_enabled }
    }
  }

  # Public Network Link Config
  talos_public_link_config_patches = local.talos_public_interface_enabled ? [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_public_link_name
      up         = true
    }
  ] : []

  talos_public_dhcp_config_patches = local.talos_public_interface_enabled && var.talos_public_ipv4_enabled ? [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_public_link_name
    }
  ] : []

  # Private Network Link Config
  talos_private_link_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_private_link_name
      up         = true
      routes     = local.talos_extra_routes
    }
  ]

  talos_private_dhcp_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_private_link_name
    }
  ]

  # Nameservers
  talos_nameservers = [
    for ns in var.talos_nameservers : ns
    if var.talos_ipv6_enabled || !strcontains(ns, ":")
  ]

  talos_resolver_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "ResolverConfig"
    nameservers = [
      for ns in local.talos_nameservers : {
        address = ns
      }
    ]
  }

  # Static Hosts (/etc/hosts)
  talos_static_hosts = concat(
    var.kube_api_hostname != null ? [
      {
        ip        = local.kube_api_private_ipv4
        hostnames = [var.kube_api_hostname]
      }
    ] : [],
    var.talos_static_hosts
  )

  talos_static_host_config_patches = [
    for ip in distinct([for entry in local.talos_static_hosts : entry.ip]) : {
      apiVersion = "v1alpha1"
      kind       = "StaticHostConfig"
      name       = ip
      hostnames = sort(distinct(flatten([
        for entry in local.talos_static_hosts :
        entry.ip == ip ? entry.hostnames : []
      ])))
    }
  ]

  # NTP
  talos_time_sync_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "TimeSyncConfig"
    ntp = {
      servers = var.talos_ntp_servers
    }
  }

  # Talos Base Config
  talos_base_config_patches = concat(
    [{
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        certSANs = local.talos_certificate_san
        kubelet = merge(
          {
            extraArgs = merge(
              {
                "cloud-provider"             = "external"
                "rotate-server-certificates" = true
              },
              var.kubernetes_kubelet_extra_args
            )
            extraConfig = {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
            }
            extraMounts = local.talos_kubelet_extra_mounts
            nodeIP = {
              validSubnets = [local.network_node_ipv4_cidr]
            }
          },
          var.kubernetes_kubelet_image != null ? {
            image = "${var.kubernetes_kubelet_image}:${var.kubernetes_version}"
          } : {}
        )
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = merge(
          {
            "net.core.somaxconn"                 = "65535"
            "net.core.netdev_max_backlog"        = "4096"
            "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}"
            "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
          },
          var.talos_sysctls_extra_args
        )
        registries           = var.talos_registries
        systemDiskEncryption = local.talos_system_disk_encryption
        features = {
          hostDNS = local.talos_host_dns
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.network_pod_ipv4_cidr]
          serviceSubnets = [local.network_service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = merge(
          {
            disabled = var.cilium_kube_proxy_replacement_enabled
          },
          var.kubernetes_proxy_image != null ? {
            image = "${var.kubernetes_proxy_image}:${var.kubernetes_version}"
          } : {}
        )
        discovery = local.talos_discovery
      }
    }],
    local.talos_public_link_config_patches,
    local.talos_public_dhcp_config_patches,
    local.talos_private_link_config_patches,
    local.talos_private_dhcp_config_patches,
    [local.talos_resolver_config_patch],
    [local.talos_time_sync_config_patch],
    local.talos_static_host_config_patches
  )
}
