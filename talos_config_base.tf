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

  talos_cloud_metadata_ipv4_cidr  = "169.254.169.254/32"
  talos_cloud_public_ipv4_gateway = "172.31.1.1"

  # Routes
  # Note: Default route (0.0.0.0/0) omits the 'network' key per Talos routing config requirements
  # See https://github.com/siderolabs/talos/issues/12521
  talos_extra_routes = [for cidr in var.talos_extra_routes : merge(
    {
      gateway = local.network_ipv4_gateway
      metric  = 512
    },
    cidr != "0.0.0.0/0" ? { destination = cidr } : {}
  )]

  # DNS Configuration
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

  # Longhorn data paths
  talos_longhorn_volume_config_patches = var.longhorn_enabled ? [
    {
      apiVersion = "v1alpha1"
      kind       = "UserVolumeConfig"
      name       = "longhorn"
      volumeType = "directory"
    }
  ] : []

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

  # CRI Configuration
  talos_cri_config_patches = !var.talos_cri_discard_unpacked_layers ? [
    {
      apiVersion = "v1alpha1"
      kind       = "CRICustomizationConfig"
      name       = "discard-unpacked-layers"
      content    = <<-EOT
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
      EOT
    }
  ] : []

  # Public Network Link Config
  talos_cloud_public_link_config_patches = local.talos_public_interface_enabled ? [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_public_link_name
      up         = true
      routes = [
        {
          destination = local.talos_cloud_metadata_ipv4_cidr
          gateway     = local.talos_cloud_public_ipv4_gateway
          metric      = 128
        }
      ]
    }
  ] : []

  talos_cloud_public_dhcp_config_patches = local.talos_public_interface_enabled && var.talos_public_ipv4_enabled ? [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_public_link_name
    }
  ] : []

  # Private Network Link Config
  talos_cloud_private_link_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "LinkConfig"
      name       = local.talos_private_link_name
      up         = true
      mtu        = local.bare_metal_enabled ? 1400 : 1450
      routes     = local.talos_extra_routes
    }
  ]

  talos_cloud_private_dhcp_config_patches = [
    {
      apiVersion = "v1alpha1"
      kind       = "DHCPv4Config"
      name       = local.talos_private_link_name
    }
  ]

  # System Volume Config
  talos_system_volume_encryption = {
    provider = "luks2"
    options  = ["no_read_workqueue", "no_write_workqueue"]
    keys = [{
      nodeID = {}
      slot   = 0
    }]
  }

  talos_system_volume_config_patches = concat(
    var.talos_state_partition_encryption_enabled ? [
      {
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "STATE"
        encryption = local.talos_system_volume_encryption
      }
    ] : [],
    var.talos_ephemeral_partition_encryption_enabled ? [
      {
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "EPHEMERAL"
        encryption = local.talos_system_volume_encryption
      }
    ] : []
  )

  # Nameservers
  talos_nameservers = [
    for ns in var.talos_nameservers : ns
    if var.talos_ipv6_enabled || !strcontains(ns, ":")
  ]

  talos_resolver_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "ResolverConfig"
    hostDNS    = local.talos_host_dns
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

  # Container Registry Configuration
  talos_registry_mirror_config_patches = [
    for name, mirror in try(var.talos_registries.mirrors, {}) : merge(
      {
        apiVersion = "v1alpha1"
        kind       = "RegistryMirrorConfig"
        name       = name
        endpoints = [
          for endpoint in try(mirror.endpoints, []) : merge(
            { url = endpoint },
            try(mirror.overridePath, null) != null ? { overridePath = mirror.overridePath } : {}
          )
        ]
      },
      try(mirror.skipFallback, null) != null ? { skipFallback = mirror.skipFallback } : {}
    )
  ]

  talos_registry_auth_config_patches = [
    for name, registry in try(var.talos_registries.config, {}) : merge(
      {
        apiVersion = "v1alpha1"
        kind       = "RegistryAuthConfig"
        name       = name
      },
      try(registry.auth.username, null) != null ? { username = registry.auth.username } : {},
      try(registry.auth.password, null) != null ? { password = registry.auth.password } : {},
      try(registry.auth.auth, null) != null ? { auth = registry.auth.auth } : {},
      try(registry.auth.identityToken, null) != null ? { identityToken = registry.auth.identityToken } : {}
    ) if try(registry.auth, null) != null
  ]

  talos_registry_tls_config_patches = [
    for name, registry in try(var.talos_registries.config, {}) : merge(
      {
        apiVersion = "v1alpha1"
        kind       = "RegistryTLSConfig"
        name       = name
      },
      try(registry.tls.clientIdentity, null) != null ? {
        clientIdentity = {
          cert = base64decode(registry.tls.clientIdentity.crt)
          key  = base64decode(registry.tls.clientIdentity.key)
        }
      } : {},
      try(registry.tls.ca, null) != null ? { ca = base64decode(registry.tls.ca) } : {},
      try(registry.tls.insecureSkipVerify, null) != null ? {
        insecureSkipVerify = registry.tls.insecureSkipVerify
      } : {}
    ) if try(registry.tls, null) != null
  ]

  # Additional trusted CA certificates
  talos_trusted_certs_config_patches = var.talos_certificates != null ? [
    for name, chain in var.talos_certificates : {
      apiVersion = "v1alpha1"
      kind       = "TrustedRootsConfig"
      name       = name
      certificates = join("\n", [
        for cert in(can(tolist(chain)) ? tolist(chain) : [tostring(chain)]) :
        trimspace(cert) if trimspace(cert) != ""
      ])
    }
  ] : []

  # Boot-time machine configuration
  talos_user_data_config_patches = concat(
    [for p in concat(local.talos_cloud_private_link_config_patches, local.talos_cloud_private_dhcp_config_patches) : p if var.cluster_access == "private"],
  )

  talos_user_data = length(local.talos_user_data_config_patches) > 0 ? join("\n---\n", [
    for patch in local.talos_user_data_config_patches : yamlencode(patch)
  ]) : null

  # Kubelet Configuration
  # Talos 1.14 removed extraMounts from the multi-document KubeletConfig. Keep the
  # legacy kubelet document only when mounts are required, for example by Longhorn.
  talos_legacy_kubelet_config_enabled = length(local.talos_kubelet_extra_mounts) > 0

  talos_common_kubelet_extra_args = merge(
    {
      "cloud-provider"             = "external"
      "rotate-server-certificates" = "true"
    },
    var.kubernetes_kubelet_extra_args
  )

  talos_common_kubelet_extra_config = {
    shutdownGracePeriod             = "90s"
    shutdownGracePeriodCriticalPods = "15s"
  }

  talos_legacy_kubelet_config = {
    extraArgs                           = local.talos_common_kubelet_extra_args
    extraConfig                         = local.talos_common_kubelet_extra_config
    defaultRuntimeSeccompProfileEnabled = true
    disableManifestsDirectory           = true
    extraMounts                         = local.talos_kubelet_extra_mounts
    image = (
      var.kubernetes_kubelet_image != null ?
      "${var.kubernetes_kubelet_image}:${var.kubernetes_version}" :
      "ghcr.io/siderolabs/kubelet:${var.kubernetes_version}"
    )
  }

  talos_kubelet_config_patch = merge(
    {
      defaultRuntimeSeccompProfileEnabled = true
      apiVersion                          = "v1alpha1"
      kind                                = "KubeletConfig"
      extraArgs                           = local.talos_common_kubelet_extra_args
      config                              = local.talos_common_kubelet_extra_config
    },
    var.kubernetes_kubelet_image != null ? {
      image = "${var.kubernetes_kubelet_image}:${var.kubernetes_version}"
    } : {}
  )

  talos_kubelet_config_patches = concat(
    local.talos_legacy_kubelet_config_enabled ? [{
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      "$patch"   = "delete"
    }] : [],
    local.talos_legacy_kubelet_config_enabled ? [] : [local.talos_kubelet_config_patch]
  )

  # Kubernetes Node Configuration
  talos_kube_node_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "KubeNodeConfig"
    nodeIP = {
      validSubnets = [local.network_node_ipv4_cidr]
    }
  }

  # Kernel Configuration
  talos_kernel_module_config_patches = [
    for module in coalesce(var.talos_kernel_modules, []) : merge(
      {
        apiVersion = "v1alpha1"
        kind       = "KernelModuleConfig"
        name       = module.name
      },
      module.parameters != null ? { parameters = module.parameters } : {}
    )
  ]

  talos_sysctl_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "SysctlConfig"
    params = merge(
      {
        "net.core.somaxconn"                 = "65535"
        "net.core.netdev_max_backlog"        = "4096"
        "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}"
        "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
      },
      var.talos_sysctls_extra_args
    )
  }

  # Kubernetes Network Configuration
  talos_kube_network_config_patch = {
    apiVersion     = "v1alpha1"
    kind           = "KubeNetworkConfig"
    dnsDomain      = var.cluster_domain
    podSubnets     = [local.network_pod_ipv4_cidr]
    serviceSubnets = [local.network_service_ipv4_cidr]
  }

  talos_kube_proxy_config_patch = merge(
    {
      apiVersion = "v1alpha1"
      kind       = "KubeProxyConfig"
      enabled    = !var.cilium_kube_proxy_replacement_enabled
    },
    var.kubernetes_proxy_image != null ? {
      image = "${var.kubernetes_proxy_image}:${var.kubernetes_version}"
    } : {}
  )

  talos_kube_flannel_config_delete_patch = {
    apiVersion = "v1alpha1"
    kind       = "KubeFlannelCNIConfig"
    "$patch"   = "delete"
  }

  talos_discovery_service_config_patches = var.talos_discovery_service_enabled ? [] : [
    {
      apiVersion = "v1alpha1"
      kind       = "DiscoveryServiceConfig"
      name       = "default"
      "$patch"   = "delete"
    }
  ]

  # Talos Common Config
  talos_common_config_patches = concat(
    [{
      machine = merge(
        {
          certSANs = local.talos_certificate_san
          logging = {
            destinations = var.talos_logging_destinations
          }
        },
        local.talos_legacy_kubelet_config_enabled ? {
          kubelet = local.talos_legacy_kubelet_config
        } : {}
      )
    }],
    local.talos_system_volume_config_patches,
    local.talos_longhorn_volume_config_patches,
    [local.talos_resolver_config_patch],
    [local.talos_time_sync_config_patch],
    local.talos_registry_mirror_config_patches,
    local.talos_registry_auth_config_patches,
    local.talos_registry_tls_config_patches,
    local.talos_static_host_config_patches,
    local.talos_trusted_certs_config_patches,
    local.talos_cri_config_patches,
    local.talos_kubelet_config_patches,
    [local.talos_kube_node_config_patch],
    local.talos_kernel_module_config_patches,
    [local.talos_sysctl_config_patch],
    [local.talos_kube_network_config_patch],
    [local.talos_kube_flannel_config_delete_patch],
    local.talos_discovery_service_config_patches
  )

  talos_cloud_config_patches = concat(
    local.talos_common_config_patches,
    [
      {
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer = {
          image = local.talos_cloud_installer_image_url
        }
        provisioning = {
          diskSelector = {
            match = "disk.dev_path == \"/dev/sda\""
          }
          wipe = false
        }
      }
    ],
    local.talos_cloud_public_link_config_patches,
    local.talos_cloud_public_dhcp_config_patches,
    local.talos_cloud_private_link_config_patches,
    local.talos_cloud_private_dhcp_config_patches
  )
}
