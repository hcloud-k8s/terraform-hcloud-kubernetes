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

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }
      routingMode           = var.cilium_routing_mode
      ipv4NativeRoutingCIDR = local.network_native_routing_ipv4_cidr
      policyCIDRMatchMode   = var.cilium_policy_cidr_match_mode
      bpf = {
        masquerade        = var.cilium_kube_proxy_replacement_enabled
        datapathMode      = var.cilium_bpf_datapath_mode
        hostLegacyRouting = local.cilium_ipsec_enabled
      }
      encryption = {
        enabled = var.cilium_encryption_enabled
        type    = var.cilium_encryption_type
      }
      k8s = {
        requireIPv4PodCIDR = true
      }
      k8sServiceHost                      = local.kube_prism_host
      k8sServicePort                      = local.kube_prism_port
      kubeProxyReplacement                = var.cilium_kube_proxy_replacement_enabled
      kubeProxyReplacementHealthzBindAddr = var.cilium_kube_proxy_replacement_enabled ? "0.0.0.0:10256" : ""
      installNoConntrackIptablesRules     = var.cilium_kube_proxy_replacement_enabled && var.cilium_routing_mode == "native"
      socketLB = {
        hostNamespaceOnly = var.cilium_socket_lb_host_namespace_only_enabled
      }
      cgroup = {
        autoMount = { enabled = false }
        hostRoot  = "/sys/fs/cgroup"
      }
      securityContext = {
        capabilities = {
          ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }
      dnsProxy = {
        enableTransparentMode = true
      }
      egressGateway = {
        enabled = var.cilium_egress_gateway_enabled
      }
      loadBalancer = {
        acceleration = var.cilium_loadbalancer_acceleration
      }
      gatewayAPI = {
        enabled               = var.cilium_gateway_api_enabled
        enableProxyProtocol   = var.cilium_gateway_api_proxy_protocol_enabled
        enableAppProtocol     = true
        enableAlpn            = true
        externalTrafficPolicy = var.cilium_gateway_api_external_traffic_policy
        gatewayClass = {
          create = tostring(var.cilium_gateway_api_enabled)
        }
      }
      hubble = {
        enabled = var.cilium_hubble_enabled
        relay   = { enabled = var.cilium_hubble_relay_enabled }
        ui      = { enabled = var.cilium_hubble_ui_enabled }
        peerService = {
          clusterDomain = var.cluster_domain
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
      operator = {
        nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
        replicas     = local.control_plane_sum > 1 ? 2 : 1
        podDisruptionBudget = {
          enabled        = true
          minAvailable   = null
          maxUnavailable = 1
        }
        topologySpreadConstraints = [
          {
            topologyKey       = "kubernetes.io/hostname"
            maxSkew           = 1
            whenUnsatisfiable = "DoNotSchedule"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name" = "cilium-operator"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }
        ]
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled  = var.cilium_service_monitor_enabled
            interval = "15s"
          }
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
