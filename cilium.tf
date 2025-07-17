data "helm_template" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository   = var.cilium_helm_repository
  chart        = var.cilium_helm_chart
  version      = var.cilium_helm_version
  kube_version = var.kubernetes_version

  set = [
    {
      name  = "operator.replicas"
      value = local.control_plane_sum > 1 ? 2 : 1
    },
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "k8s.requireIPv4PodCIDR"
      value = true
    },
    {
      name  = "routingMode"
      value = "native"
    },
    {
      name  = "ipv4NativeRoutingCIDR"
      value = local.native_routing_cidr
    },
    {
      name  = "kubeProxyReplacement"
      value = true
    },
    {
      name  = "kubeProxyReplacementHealthzBindAddr"
      value = "0.0.0.0:10256"
    },
    {
      name  = "bpf.masquerade"
      value = true
    },
    # Netkit requires kernel >= 6.8
    # {
    #   name  = "bpf.datapathMode"
    #   value = "netkit"
    # },
    {
      name  = "loadBalancer.acceleration"
      value = "native"
    },
    {
      name  = "installNoConntrackIptablesRules"
      value = true
    },

    {
      name  = "egressGateway.enabled"
      value = var.cilium_egress_gateway_enabled
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = false
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = local.kube_prism_host
    },
    {
      name  = "k8sServicePort"
      value = local.kube_prism_port
    },

    {
      name  = "hubble.peerService.clusterDomain"
      value = var.cluster_domain
    }
  ]

  values = [
    yamlencode({
      encryption = {
        enabled = var.cilium_encryption_enabled
        type    = "wireguard"
      }
      hubble = {
        enabled = var.cilium_hubble_enabled
        relay   = { enabled = var.cilium_hubble_relay_enabled }
        ui      = { enabled = var.cilium_hubble_ui_enabled }
      }
      operator = {
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled  = var.cilium_service_monitor_enabled
            interval = "15s"
          }
        }
      }
      prometheus = {
        enabled = true
        serviceMonitor = {
          enabled        = var.cilium_service_monitor_enabled
          trustCRDsExist = var.cilium_service_monitor_enabled
          interval       = "15s"
        }
      }
    }),
    yamlencode(var.cilium_helm_values)
  ]
}

locals {
  cilium_manifest = var.cilium_enabled ? {
    name     = "cilium"
    contents = data.helm_template.cilium.manifest
  } : null
}
