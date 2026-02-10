locals {
  # HostnameConfig document
  # Talos will prioritize DHCP to provide hostname from Hetzner Cloud
  # Otherwise will generate the hostname based on machine identity
  talos_manifest_hostnameconfig = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "HostnameConfig"
    auto       = "stable"
  })
}
