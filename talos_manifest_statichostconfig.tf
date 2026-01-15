locals {
  # User defined extra host entries
  talos_extra_host_entries = concat(
    var.kube_api_hostname != null ? [
      {
        ip      = local.kube_api_private_ipv4
        aliases = [var.kube_api_hostname]
      }
    ] : [],
    var.talos_extra_host_entries
  )

  # StaticHostConfig documents - /etc/hosts entries
  talos_manifest_statichostconfigs = length(local.talos_extra_host_entries) > 0 ? trimspace(join(
    "\n---\n",
    [
      for entry in local.talos_extra_host_entries : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "StaticHostConfig"
        name       = entry.ip
        hostnames  = entry.aliases
      })
    ]
  )) : ""
}
