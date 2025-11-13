locals {
  cluster_autoscaler_enabled          = length(local.cluster_autoscaler_nodepools) > 0
  cluster_autoscaler_hostname_pattern = "^${var.cluster_name}-(${join("|", distinct([for np in local.cluster_autoscaler_nodepools : np.name]))})-[0-9a-f]+$"

  cluster_autoscaler_release_name       = "cluster-autoscaler"
  cluster_autoscaler_cloud_provider     = "hetzner"
  cluster_autoscaler_config_secret_name = "${local.cluster_autoscaler_release_name}-${local.cluster_autoscaler_cloud_provider}-config"

  cluster_autoscaler_cluster_config_manifest = local.cluster_autoscaler_enabled ? {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = local.cluster_autoscaler_config_secret_name
      namespace = "kube-system"
    }
    data = {
      cluster-config = base64encode(jsonencode(
        {
          imagesForArch = {
            arm64 = local.image_label_selector,
            amd64 = local.image_label_selector
          },
          nodeConfigs = {
            for nodepool in local.cluster_autoscaler_nodepools : "${var.cluster_name}-${nodepool.name}" => {
              cloudInit     = data.talos_machine_configuration.cluster_autoscaler[nodepool.name].machine_configuration,
              labels        = nodepool.labels
              taints        = nodepool.taints
              subnetIPRange = hcloud_network_subnet.autoscaler[nodepool.name].ip_range,
            }
          }
        }
      ))
    }
  } : null
}

data "helm_template" "cluster_autoscaler" {
  count = local.cluster_autoscaler_enabled ? 1 : 0

  name      = local.cluster_autoscaler_release_name
  namespace = "kube-system"

  repository   = var.cluster_autoscaler_helm_repository
  chart        = var.cluster_autoscaler_helm_chart
  version      = var.cluster_autoscaler_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      cloudProvider = local.cluster_autoscaler_cloud_provider
      replicaCount  = local.control_plane_sum > 1 ? 2 : 1
      podDisruptionBudget = {
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
              "app.kubernetes.io/instance" = local.cluster_autoscaler_release_name
              "app.kubernetes.io/name"     = "${local.cluster_autoscaler_cloud_provider}-${var.cluster_autoscaler_helm_chart}"
            }
          }
          matchLabelKeys = ["pod-template-hash"]
        }
      ]
      nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          effect   = "NoSchedule"
          operator = "Exists"
        }
      ]
      autoscalingGroups = [
        for np in local.cluster_autoscaler_nodepools : {
          name         = "${var.cluster_name}-${np.name}"
          minSize      = np.min
          maxSize      = np.max
          instanceType = np.server_type
          region       = np.location
        }
      ]
      extraEnv = {
        HCLOUD_CLUSTER_CONFIG_FILE     = "/config/cluster-config"
        HCLOUD_SERVER_CREATION_TIMEOUT = "10"
        HCLOUD_FIREWALL                = tostring(hcloud_firewall.this.id)
        HCLOUD_SSH_KEY                 = tostring(hcloud_ssh_key.this.id)
        HCLOUD_PUBLIC_IPV4             = tostring(var.talos_public_ipv4_enabled)
        HCLOUD_PUBLIC_IPV6             = tostring(var.talos_public_ipv6_enabled)
        HCLOUD_NETWORK                 = tostring(local.hcloud_network_id)
      }
      extraEnvSecrets = {
        HCLOUD_TOKEN = {
          name = "hcloud"
          key  = "token"
        }
      }
      extraVolumeSecrets = {
        "${local.cluster_autoscaler_config_secret_name}" = {
          name      = local.cluster_autoscaler_config_secret_name
          mountPath = "/config"
        }
      }
    }),
    yamlencode(var.cluster_autoscaler_helm_values)
  ]

  depends_on = [
    terraform_data.amd64_image,
    terraform_data.arm64_image,
  ]
}

locals {
  cluster_autoscaler_manifest = local.cluster_autoscaler_enabled ? {
    name     = "cluster-autoscaler"
    contents = <<-EOF
      ${data.helm_template.cluster_autoscaler[0].manifest}
      ---
      ${yamlencode(local.cluster_autoscaler_cluster_config_manifest)}
    EOF
  } : null
}
