locals {
  # Registry documents - RegistryMirrorConfig, RegistryAuthConfig, RegistryTLSConfig
  # Combined into a single multi-document YAML string
  talos_manifest_registry_documents = var.talos_registries == null ? "" : trimspace(join(
    "\n---\n",
    compact(concat(
      # RegistryMirrorConfig documents - configure registry mirrors
      [
        for registry, config in var.talos_registries : config.endpoints != null ? yamlencode(
          merge(
            {
              apiVersion = "v1alpha1"
              kind       = "RegistryMirrorConfig"
              name       = registry
              endpoints  = config.endpoints
            },
            config.skipFallback ? { skipFallback = true } : {}
          )
        ) : null
      ],
      # RegistryAuthConfig documents - configure authentication
      [
        for registry, config in var.talos_registries :
        (config.username != null || config.password != null || config.auth != null || config.identityToken != null) ?
        yamlencode(
          merge(
            {
              apiVersion = "v1alpha1"
              kind       = "RegistryAuthConfig"
              name       = registry
            },
            config.username != null ? { username = config.username } : {},
            config.password != null ? { password = config.password } : {},
            config.auth != null ? { auth = config.auth } : {},
            config.identityToken != null ? { identityToken = config.identityToken } : {}
          )
        ) : null
      ],
      # RegistryTLSConfig documents - configure TLS
      [
        for registry, config in var.talos_registries :
        (config.ca != null || config.clientIdentity != null || config.insecureSkipVerify != false) ?
        yamlencode(
          merge(
            {
              apiVersion = "v1alpha1"
              kind       = "RegistryTLSConfig"
              name       = registry
            },
            config.ca != null ? { ca = config.ca } : {},
            config.clientIdentity != null ? { clientIdentity = config.clientIdentity } : {},
            config.insecureSkipVerify ? { insecureSkipVerify = true } : {}
          )
        ) : null
      ]
    ))
  ))
}
