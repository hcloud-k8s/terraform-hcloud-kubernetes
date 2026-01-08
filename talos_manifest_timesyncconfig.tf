locals {
  # TimeSyncConfig document - NTP configuration
  talos_manifest_timesyncconfig = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "TimeSyncConfig"
    ntp = {
      servers = var.talos_time_servers
    }
  })
}
