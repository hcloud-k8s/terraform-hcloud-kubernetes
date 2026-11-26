locals {
  # The common patches carry cloud-provider=external, which keeps the uninitialized taint on nodes no cloud controller manager knows.
  external_common_config_patches = [
    for patch in local.talos_common_config_patches : patch if try(patch.kind, null) != "KubeletConfig"
  ]

  external_talos_config_patches = {
    for server_name, server in local.external_servers : server_name => [
      merge(
        local.talos_kubelet_config_patch,
        {
          extraArgs = merge(
            { for name, value in local.talos_common_kubelet_extra_args : name => value if name != "cloud-provider" },
            { "provider-id" = server.provider_id }
          )
          config = merge(
            local.talos_common_kubelet_extra_config,
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
      ),
      {
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer = {
          image = local.talos_external_installer_image_urls[server.nodepool]
        }
        provisioning = {
          diskSelector = {
            match = "disk.serial == ${jsonencode(server.install_disk_serial)}"
          }
          wipe = false
        }
      },
      {
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = server.name
        auto       = "off"
      },
      {
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        labels     = local.external_nodepools_map[server.nodepool].labels
        taints = {
          for taint in local.external_nodepools_map[server.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
        }
      }
    ]
  }
}

data "talos_machine_configuration" "external" {
  for_each = local.external_servers

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.external_common_config_patches : yamlencode(patch)],
    [for patch in local.external_talos_config_patches[each.key] : yamlencode(patch)],
    local.external_nodepools_map[each.value.nodepool].config_patches
  )
}
