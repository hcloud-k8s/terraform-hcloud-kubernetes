locals {
  # UserVolumeConfig documents
  # Directory-type volumes create directories at /var/mnt/<name>
  # without requiring full block device partitions

  # Control Plane directory volumes
  control_plane_uservolumeconfigs = length(var.control_plane_directory_volumes) > 0 ? trimspace(join(
    "\n---\n",
    [
      for name in var.control_plane_directory_volumes : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = name
        volumeType = "directory"
      })
    ]
  )) : ""

  # Worker directory volumes
  worker_uservolumeconfigs = length(var.worker_directory_volumes) > 0 ? trimspace(join(
    "\n---\n",
    [
      for name in var.worker_directory_volumes : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = name
        volumeType = "directory"
      })
    ]
  )) : ""

  # Cluster Autoscaler directory volumes
  cluster_autoscaler_uservolumeconfigs = length(var.cluster_autoscaler_directory_volumes) > 0 ? trimspace(join(
    "\n---\n",
    [
      for name in var.cluster_autoscaler_directory_volumes : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = name
        volumeType = "directory"
      })
    ]
  )) : ""
}
