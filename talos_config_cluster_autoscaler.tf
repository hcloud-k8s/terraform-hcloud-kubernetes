locals {
  # Autoscaler Config
  autoscaler_nodepool_talos_config_patch = {
    for nodepool in local.cluster_autoscaler_nodepools : nodepool.name => [
      {
        machine = {
          nodeLabels      = nodepool.labels
          nodeAnnotations = nodepool.annotations
          kubelet = {
            extraConfig = merge(
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
          }
        }
      }
    ]
  }
}

data "talos_machine_configuration" "cluster_autoscaler" {
  for_each = { for nodepool in local.cluster_autoscaler_nodepools : nodepool.name => nodepool }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_base_config_patches : yamlencode(patch)],
    [for patch in local.autoscaler_nodepool_talos_config_patch[each.key] : yamlencode(patch)],
    [for patch in var.cluster_autoscaler_config_patches : yamlencode(patch)]
  )
}
