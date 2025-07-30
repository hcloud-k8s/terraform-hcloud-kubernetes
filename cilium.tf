locals {
  # Cilium IPSec Configuration
  cilium_ipsec_enabled = var.cilium_encryption_enabled && var.cilium_encryption_type == "ipsec"

  # Key configuration when IPSec is enabled
  cilium_ipsec_key_config = local.cilium_ipsec_enabled ? {
    next_id = var.cilium_ipsec_key_id % 15 + 1
    format  = "${var.cilium_ipsec_key_id}+ ${var.cilium_ipsec_algorithm} ${random_bytes.cilium_ipsec_key[0].hex} 128"
  } : null

  # Kubernetes Secret manifest
  cilium_ipsec_keys_manifest = local.cilium_ipsec_enabled ? {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"

    metadata = {
      name      = "cilium-ipsec-keys"
      namespace = "kube-system"

      annotations = {
        "cilium.io/key-id"        = tostring(var.cilium_ipsec_key_id)
        "cilium.io/key-algorithm" = var.cilium_ipsec_algorithm
        "cilium.io/key-size"      = tostring(var.cilium_ipsec_key_size)
      }
    }

    data = {
      keys = base64encode(local.cilium_ipsec_key_config.format)
    }
  } : null
}

# Generate random key when IPSec is enabled
resource "random_bytes" "cilium_ipsec_key" {
  count  = local.cilium_ipsec_enabled ? 1 : 0
  length = ((var.cilium_ipsec_key_size / 8) + 4) # AES Key + 4 bytes salt

  # Keepers to force regeneration when key_id changes
  keepers = {
    key_id = var.cilium_ipsec_key_id
  }
}


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
    {
      name  = "bpf.datapathMode"
      value = var.cilium_bpf_datapath_mode
    },
    {
      name  = "loadBalancer.acceleration"
      value = "native"
    },
    {
      name  = "installNoConntrackIptablesRules"
      value = true
    },
    # IPSec
    {
      name  = "bpf.hostLegacyRouting"
      value = local.cilium_ipsec_enabled
    },
    {
      name  = "dnsProxy.enableTransparentMode"
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
        type    = var.cilium_encryption_type
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
    contents = <<-EOF
      ${yamlencode(local.cilium_ipsec_keys_manifest)}
      ---
      ${data.helm_template.cilium.manifest}
    EOF
  } : null
}
