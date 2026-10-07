locals {
  # Worker Config
  worker_talos_config_patches = {
    for name, node in hcloud_server.worker : name => concat(
      [{
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        labels = merge(
          local.worker_nodepools_map[node.labels.nodepool].labels,
          { "nodeid" = tostring(node.id) }
        )
        annotations = local.worker_nodepools_map[node.labels.nodepool].annotations
        taints = {
          for taint in local.worker_nodepools_map[node.labels.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
        }
      }],
      local.talos_legacy_kubelet_config_enabled ? [{
        machine = {
          kubelet = {
            extraConfig = merge(
              {
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
      }] : [],
      local.talos_legacy_kubelet_config_enabled ? [] : [{
        apiVersion = "v1alpha1"
        kind       = "KubeletConfig"
        config = merge(
          {
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
      }],
      [{
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = name
        auto       = "off"
      }]
    )
  }
}

data "talos_machine_configuration" "worker" {
  for_each = toset(keys(hcloud_server.worker))

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_cloud_config_patches : yamlencode(patch)],
    [for patch in local.worker_talos_config_patches[each.key] : yamlencode(patch)],
    [for patch in var.worker_config_patches : yamlencode(patch)]
  )
}
