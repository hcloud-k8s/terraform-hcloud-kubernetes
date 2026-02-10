locals {
  talos_allow_scheduling_on_control_planes = coalesce(var.cluster_allow_scheduling_on_control_planes, (local.worker_sum + local.cluster_autoscaler_max_sum) == 0)

  # Kubernetes inline manifests for Talos
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
    local.kube_rbac_manifest != null ? [local.kube_rbac_manifest] : [],
    local.kube_oidc_manifest != null ? [local.kube_oidc_manifest] : [],
    var.talos_extra_inline_manifests != null ? var.talos_extra_inline_manifests : []
  )

  # Kubernetes remote manifests for Talos
  talos_remote_manifests = concat(
    var.talos_ccm_enabled ? [
      "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/${var.talos_ccm_version}/docs/deploy/cloud-controller-manager-daemonset.yml"
    ] : [],
    var.prometheus_operator_crds_enabled ? [
      "https://github.com/prometheus-operator/prometheus-operator/releases/download/${var.prometheus_operator_crds_version}/stripped-down-crds.yaml"
    ] : [],
    var.gateway_api_crds_enabled ? [
      "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crds_version}/${var.gateway_api_crds_release_channel}-install.yaml"
    ] : [],
    var.talos_extra_remote_manifests != null ? var.talos_extra_remote_manifests : []
  )

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

  # DNS Configuration
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

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

  # Shared Talos Configuration
  talos_config_install = {
    image           = local.talos_installer_image_url
    extraKernelArgs = var.talos_extra_kernel_args
  }

  talos_config_sysctls = merge(
    {
      "net.core.somaxconn"                 = "65535"
      "net.core.netdev_max_backlog"        = "4096"
      "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}"
      "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
    },
    var.talos_sysctls_extra_args
  )

  talos_config_kubelet_args = merge(
    {
      "cloud-provider"             = "external"
      "rotate-server-certificates" = true
    },
    var.kubernetes_kubelet_extra_args
  )

  talos_config_kubelet_extra_config_base = {
    shutdownGracePeriod             = "90s"
    shutdownGracePeriodCriticalPods = "15s"
  }

  talos_config_kubelet_nodeip = {
    validSubnets = [local.network_node_ipv4_cidr]
  }

  talos_config_cluster_base = {
    network = {
      dnsDomain      = var.cluster_domain
      podSubnets     = [local.network_pod_ipv4_cidr]
      serviceSubnets = [local.network_service_ipv4_cidr]
      cni            = { name = "none" }
    }
    proxy = {
      disabled = var.cilium_kube_proxy_replacement_enabled
    }
    discovery = local.talos_discovery
  }

  # Control Plane Config
  control_plane_talos_config_patch = {
    for node in hcloud_server.control_plane : node.name => {
      machine = {
        install = local.talos_config_install
        nodeLabels = merge(
          local.talos_allow_scheduling_on_control_planes ? { "node.kubernetes.io/exclude-from-external-load-balancers" = { "$patch" = "delete" } } : {},
          local.control_plane_nodepools_map[node.labels.nodepool].labels,
          { "nodeid" = tostring(node.id) }
        )
        nodeAnnotations = local.control_plane_nodepools_map[node.labels.nodepool].annotations
        nodeTaints = {
          for taint in local.control_plane_nodepools_map[node.labels.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
        }
        certSANs = local.talos_certificate_san
        kubelet = {
          extraArgs = local.talos_config_kubelet_args
          extraConfig = merge(
            local.talos_config_kubelet_extra_config_base,
            {
              registerWithTaints = local.control_plane_nodepools_map[node.labels.nodepool].taints
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
          nodeIP      = local.talos_config_kubelet_nodeip
        }
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = local.talos_config_sysctls
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
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = merge(
        local.talos_config_cluster_base,
        {
          allowSchedulingOnControlPlanes = local.talos_allow_scheduling_on_control_planes
          coreDNS = {
            disabled = !var.talos_coredns_enabled
          }
          apiServer = {
            admissionControl = var.kube_api_admission_control
            certSANs         = local.talos_certificate_san,
            extraArgs = merge(
              { "enable-aggregator-routing" = true },
              local.talos_kube_oidc_configuration,
              var.kube_api_extra_args
            )
          }
          controllerManager = {
            extraArgs = {
              "cloud-provider" = "external"
              "bind-address"   = "0.0.0.0"
            }
          }
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
            manifests = local.talos_remote_manifests
          }
        }
      )
    }
  }

  # Worker Config
  worker_talos_config_patch = {
    for node in hcloud_server.worker : node.name => {
      machine = {
        install = local.talos_config_install
        nodeLabels = merge(
          local.worker_nodepools_map[node.labels.nodepool].labels,
          { "nodeid" = tostring(node.id) }
        )
        nodeAnnotations = local.worker_nodepools_map[node.labels.nodepool].annotations
        certSANs        = local.talos_certificate_san
        kubelet = {
          extraArgs = local.talos_config_kubelet_args
          extraConfig = merge(
            local.talos_config_kubelet_extra_config_base,
            {
              registerWithTaints = local.worker_nodepools_map[node.labels.nodepool].taints
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
          nodeIP      = local.talos_config_kubelet_nodeip
        }
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = local.talos_config_sysctls
        features = {
          hostDNS = local.talos_host_dns
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = local.talos_config_cluster_base
    }
  }

  # Autoscaler Config
  autoscaler_talos_config_patch = {
    for nodepool in local.cluster_autoscaler_nodepools : nodepool.name => {
      machine = {
        install         = local.talos_config_install
        nodeLabels      = nodepool.labels
        nodeAnnotations = nodepool.annotations
        certSANs        = local.talos_certificate_san
        kubelet = {
          extraArgs = local.talos_config_kubelet_args
          extraConfig = merge(
            local.talos_config_kubelet_extra_config_base,
            {
              registerWithTaints = nodepool.taints
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
          nodeIP      = local.talos_config_kubelet_nodeip
        }
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = local.talos_config_sysctls
        features = {
          hostDNS = local.talos_host_dns
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = local.talos_config_cluster_base
    }
  }
}