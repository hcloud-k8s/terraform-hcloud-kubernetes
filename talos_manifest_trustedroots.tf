locals {
  # TrustedRootsConfig documents - additional trusted CA certificates
  talos_manifest_trustedroots_documents = var.talos_trusted_roots == null ? "" : trimspace(join(
    "\n---\n",
    [
      for name, certificates in var.talos_trusted_roots : yamlencode({
        apiVersion   = "v1alpha1"
        kind         = "TrustedRootsConfig"
        name         = name
        certificates = certificates
      })
    ]
  ))
}
