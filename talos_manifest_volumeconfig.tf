locals {
  # VolumeConfig documents
  talos_manifest_volumeconfigs = trimspace(join(
    "\n---\n",
    compact([
      # STATE partition (/system/state) - persistent system data
      var.talos_state_partition_encryption_enabled ? yamlencode({
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "STATE"
        encryption = {
          provider = "luks2"
          options  = ["no_read_workqueue", "no_write_workqueue"]
          keys     = [{ nodeID = {}, slot = 0 }]
        }
      }) : null,
      # EPHEMERAL partition (/var) - temporary data
      var.talos_ephemeral_partition_encryption_enabled ? yamlencode({
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "EPHEMERAL"
        encryption = {
          provider = "luks2"
          options  = ["no_read_workqueue", "no_write_workqueue"]
          keys     = [{ nodeID = {}, slot = 0 }]
        }
      }) : null,
    ])
  ))
}
