locals {
  # User defined nameservers
  talos_nameservers = [
    for ns in var.talos_nameservers : ns
    if var.talos_ipv6_enabled || !strcontains(ns, ":")
  ]

  # ResolverConfig document - DNS nameserver configuration
  talos_manifest_resolverconfig = length(local.talos_nameservers) > 0 ? yamlencode({
    apiVersion = "v1alpha1"
    kind       = "ResolverConfig"
    nameservers = [
      for ns in local.talos_nameservers : {
        address = ns
      }
    ]
  }) : null
}
