locals {
  # Shared configuration documents applied to all node types
  talos_common_config_patches = concat(
    # HostnameConfig document
    [local.talos_manifest_hostnameconfig],
    # ResolverConfig document - DNS nameservers
    local.talos_manifest_resolverconfig != null ? [local.talos_manifest_resolverconfig] : [],
    # TimeSyncConfig document - NTP configuration
    [local.talos_manifest_timesyncconfig],
    # StaticHostConfig documents - /etc/hosts entries
    local.talos_manifest_statichostconfigs != "" ? [local.talos_manifest_statichostconfigs] : [],
    # VolumeConfig documents - system disk encryption
    local.talos_manifest_volumeconfigs != "" ? [local.talos_manifest_volumeconfigs] : [],
    # OOMConfig document - Out of Memory handler configuration
    local.talos_manifest_oomconfig != null ? [local.talos_manifest_oomconfig] : [],
    # Registry documents - RegistryMirrorConfig, RegistryAuthConfig, RegistryTLSConfig
    local.talos_manifest_registry_documents != "" ? [local.talos_manifest_registry_documents] : [],
    # TrustedRootsConfig documents - additional trusted CA certificates
    local.talos_manifest_trustedroots_documents != "" ? [local.talos_manifest_trustedroots_documents] : []
  )
}

data "talos_machine_configuration" "control_plane" {
  for_each = { for node in hcloud_server.control_plane : node.name => node }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    # Main v1alpha1 machine configuration
    [yamlencode(local.control_plane_talos_config_patch[each.key])],
    # User-provided configuration patches
    [for patch in var.control_plane_config_patches : yamlencode(patch)],
    # Network documents
    [local.control_plane_network_documents],
    # UserVolumeConfig documents
    local.control_plane_uservolumeconfigs != "" ? [local.control_plane_uservolumeconfigs] : [],
    # Common configuration documents
    local.talos_common_config_patches
  )
}

data "talos_machine_configuration" "worker" {
  for_each = { for node in hcloud_server.worker : node.name => node }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    # Main v1alpha1 machine configuration
    [yamlencode(local.worker_talos_config_patch[each.key])],
    # User-provided configuration patches
    [for patch in var.worker_config_patches : yamlencode(patch)],
    # Network documents
    [local.worker_network_documents],
    # UserVolumeConfig documents
    local.worker_uservolumeconfigs != "" ? [local.worker_uservolumeconfigs] : [],
    # Common configuration documents
    local.talos_common_config_patches
  )
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
    # Main v1alpha1 machine configuration
    [yamlencode(local.autoscaler_talos_config_patch[each.key])],
    # User-provided configuration patches
    [for patch in var.cluster_autoscaler_config_patches : yamlencode(patch)],
    # Network documents
    [local.worker_network_documents],
    # UserVolumeConfig documents
    local.cluster_autoscaler_uservolumeconfigs != "" ? [local.cluster_autoscaler_uservolumeconfigs] : [],
    # Common configuration documents
    local.talos_common_config_patches
  )
}
