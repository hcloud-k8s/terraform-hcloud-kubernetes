locals {
  allow_scheduling_on_control_plane = ((local.worker_sum + local.cluster_autoscaler_max_sum) == 0)

  # Kubernetes Manifests for Talos
  talos_inline_manifests = concat(
    [local.hcloud_secret_manifest],
    local.cilium_manifest != null ? [local.cilium_manifest] : [],
    local.hcloud_ccm_manifest != null ? [local.hcloud_ccm_manifest] : [],
    local.hcloud_csi_manifest != null ? [local.hcloud_csi_manifest] : [],
    local.talos_backup_manifest != null ? [local.talos_backup_manifest] : [],
    local.longhorn_manifest != null ? [local.longhorn_manifest] : [],
    local.metrics_server_manifest != null ? [local.metrics_server_manifest] : [],
    local.cert_manager_manifest != null ? [local.cert_manager_manifest] : [],
    local.ingress_nginx_manifest != null ? [local.ingress_nginx_manifest] : [],
    local.cluster_autoscaler_manifest != null ? [local.cluster_autoscaler_manifest] : [],
    var.talos_extra_inline_manifests != null ? var.talos_extra_inline_manifests : []
  )
  talos_manifests = concat(
    var.talos_ccm_enabled ? ["https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/${var.talos_ccm_version}/docs/deploy/cloud-controller-manager-daemonset.yml"] : [],
    var.prometheus_operator_crds_enabled ? ["https://github.com/prometheus-operator/prometheus-operator/releases/download/${var.prometheus_operator_crds_version}/stripped-down-crds.yaml"] : [],
    var.talos_extra_remote_manifests != null ? var.talos_extra_remote_manifests : []
  )

  # Talos and Kubernetes Certificates
  certificate_san = sort(
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

  # DNS Configuration
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

  talos_nameservers = [
    for ns in var.talos_nameservers : ns
    if var.talos_ipv6_enabled || !strcontains(ns, ":")
  ]

  # Routes
  talos_extra_routes = [for cidr in var.talos_extra_routes : {
    network = cidr
    gateway = local.network_ipv4_gateway
    metric  = 512
  }]

  # Interface Configuration
  talos_public_interface_enabled = var.talos_public_ipv4_enabled || var.talos_public_ipv6_enabled

  # Extra Host Entries
  extra_host_entries = concat(
    var.kube_api_hostname != null ? [
      {
        ip      = local.kube_api_private_ipv4
        aliases = [var.kube_api_hostname]
      }
    ] : [],
    var.talos_extra_host_entries
  )

  # Disk Encryption Configuration
  systemDiskEncryption = merge(
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

  # Control Plane Config
  control_plane_talos_config_patch = {
    for node in hcloud_server.control_plane : node.name => {
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        nodeLabels = merge(
          local.allow_scheduling_on_control_plane ? { "node.kubernetes.io/exclude-from-external-load-balancers" = { "$patch" = "delete" } } : {},
          local.control_plane_nodepools_map[node.labels.nodepool].labels
        )
        nodeAnnotations = local.control_plane_nodepools_map[node.labels.nodepool].annotations
        nodeTaints = {
          for taint in local.control_plane_nodepools_map[node.labels.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
        }
        certSANs = local.certificate_san
        network = {
          interfaces = concat(
            local.talos_public_interface_enabled ? [{
              interface = "eth0"
              dhcp      = true
              dhcpOptions = {
                ipv4 = var.talos_public_ipv4_enabled
                ipv6 = false
              }
              vip = local.control_plane_public_vip_ipv4_enabled ? {
                ip = local.control_plane_public_vip_ipv4
                hcloud = {
                  apiToken = var.hcloud_token
                }
              } : null
            }] : [],
            [{
              interface = local.talos_public_interface_enabled ? "eth1" : "eth0"
              dhcp      = true
              routes    = local.talos_extra_routes
              vip = var.control_plane_private_vip_ipv4_enabled ? {
                ip = local.control_plane_private_vip_ipv4
                hcloud = {
                  apiToken = var.hcloud_token
                }
              } : null
            }]
          )
          nameservers      = local.talos_nameservers
          extraHostEntries = local.extra_host_entries
        }
        kubelet = {
          extraArgs = merge(
            {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
            },
            var.kubernetes_kubelet_extra_args
          )
          extraConfig = merge(
            {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
              registerWithTaints              = local.control_plane_nodepools_map[node.labels.nodepool].taints
              systemReserved = {
                cpu               = "250m"
                memory            = "300Mi"
                ephemeral-storage = "1Gi"
              }
              kubeReserved = {
                cpu               = "250m"
                memory            = "350Mi"
                ephemeral-storage = "1Gi"
              }
            },
            var.kubernetes_kubelet_extra_config
          )
          extraMounts = local.talos_kubelet_extra_mounts
          nodeIP = {
            validSubnets = [local.node_ipv4_cidr]
          }
        }
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = merge(
          {
            "net.core.somaxconn"                 = "65535",
            "net.core.netdev_max_backlog"        = "4096",
            "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}",
            "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
          },
          var.talos_sysctls_extra_args
        )
        registries           = var.talos_registries
        systemDiskEncryption = local.systemDiskEncryption
        features = {
          kubernetesTalosAPIAccess = {
            enabled = true,
            allowedRoles = [
              "os:reader",
              "os:etcd:backup"
            ],
            allowedKubernetesNamespaces = ["kube-system"]
          },
          hostDNS = local.talos_host_dns
        }
        time = {
          servers = var.talos_time_servers
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = local.allow_scheduling_on_control_plane
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.pod_ipv4_cidr]
          serviceSubnets = [local.service_ipv4_cidr]
          cni            = { name = "none" }
        }
        coreDNS = {
          disabled = !var.talos_coredns_enabled
        }
        proxy = {
          disabled = true
        }
        apiServer = {
          admissionControl = var.kube_api_admission_control
          certSANs         = local.certificate_san,
          extraArgs = merge(
            { "enable-aggregator-routing" = true },
            var.kube_api_extra_args
          )
        }
        controllerManager = {
          extraArgs = {
            "cloud-provider" = "external"
            "bind-address"   = "0.0.0.0"
          }
        }
        discovery = local.talos_discovery
        etcd = {
          advertisedSubnets = [hcloud_network_subnet.control_plane.ip_range]
          extraArgs = {
            "listen-metrics-urls" = "http://0.0.0.0:2381"
          }
        }
        scheduler = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        adminKubeconfig = {
          certLifetime = "87600h"
        }
        inlineManifests = local.talos_inline_manifests
        externalCloudProvider = {
          enabled   = true,
          manifests = local.talos_manifests
        }
      }
    }
  }

  # Worker Config
  worker_talos_config_patch = {
    for node in hcloud_server.worker : node.name => {
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        nodeLabels      = local.worker_nodepools_map[node.labels.nodepool].labels
        nodeAnnotations = local.worker_nodepools_map[node.labels.nodepool].annotations
        certSANs        = local.certificate_san
        network = {
          interfaces = concat(
            local.talos_public_interface_enabled ? [{

              interface = "eth0"
              dhcp      = true
              dhcpOptions = {
                ipv4 = var.talos_public_ipv4_enabled
                ipv6 = false
              }
            }] : [],
            [{
              interface = local.talos_public_interface_enabled ? "eth1" : "eth0"
              dhcp      = true
              routes    = local.talos_extra_routes
            }]
          )
          nameservers      = local.talos_nameservers
          extraHostEntries = local.extra_host_entries
        }
        kubelet = {
          extraArgs = merge(
            {
              "cloud-provider"             = "external",
              "rotate-server-certificates" = true
            },
            var.kubernetes_kubelet_extra_args
          )
          extraConfig = merge(
            {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
              registerWithTaints              = local.worker_nodepools_map[node.labels.nodepool].taints
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
          extraMounts = local.talos_kubelet_extra_mounts
          nodeIP = {
            validSubnets = [local.node_ipv4_cidr]
          }
        }
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
        systemDiskEncryption = local.systemDiskEncryption
        features = {
          hostDNS = local.talos_host_dns
        }
        time = {
          servers = var.talos_time_servers
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.pod_ipv4_cidr]
          serviceSubnets = [local.service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = {
          disabled = true
        }
        discovery = local.talos_discovery
      }
    }
  }

  # Autoscaler Config
  autoscaler_nodepool_talos_config_patch = {
    for nodepool in local.cluster_autoscaler_nodepools : nodepool.name => {
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        nodeLabels      = nodepool.labels
        nodeAnnotations = nodepool.annotations
        certSANs        = local.certificate_san
        network = {
          interfaces = concat(
            local.talos_public_interface_enabled ? [{

              interface = "eth0"
              dhcp      = true
              dhcpOptions = {
                ipv4 = var.talos_public_ipv4_enabled
                ipv6 = false
              }
            }] : [],
            [{
              interface = local.talos_public_interface_enabled ? "eth1" : "eth0"
              dhcp      = true
              routes    = local.talos_extra_routes
            }]
          )
          nameservers      = local.talos_nameservers
          extraHostEntries = local.extra_host_entries
        }
        kubelet = {
          extraArgs = merge(
            {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
            },
            var.kubernetes_kubelet_extra_args
          )
          extraConfig = merge(
            {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
              registerWithTaints              = nodepool.taints
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
          extraMounts = local.talos_kubelet_extra_mounts
          nodeIP = {
            validSubnets = [local.node_ipv4_cidr]
          }
        }
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
        systemDiskEncryption = local.systemDiskEncryption
        features = {
          hostDNS = local.talos_host_dns
        }
        time = {
          servers = var.talos_time_servers
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.pod_ipv4_cidr]
          serviceSubnets = [local.service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = {
          disabled = true
        }
        discovery = local.talos_discovery
      }
    }
  }
}

data "talos_machine_configuration" "control_plane" {
  for_each = { for node in hcloud_server.control_plane : node.name => node }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode(local.control_plane_talos_config_patch[each.key]),
    yamlencode(var.control_plane_config_patches)
  ]
  docs     = false
  examples = false
}

data "talos_machine_configuration" "worker" {
  for_each = { for node in hcloud_server.worker : node.name => node }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode(local.worker_talos_config_patch[each.key]),
    yamlencode(var.worker_config_patches)
  ]
  docs     = false
  examples = false
}

data "talos_machine_configuration" "cluster_autoscaler" {
  for_each = { for nodepool in local.cluster_autoscaler_nodepools : nodepool.name => nodepool }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode(local.autoscaler_nodepool_talos_config_patch[each.key]),
    yamlencode(var.cluster_autoscaler_config_patches)
  ]
  docs     = false
  examples = false
}
