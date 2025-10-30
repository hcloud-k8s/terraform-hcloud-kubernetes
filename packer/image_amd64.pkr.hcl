variable "cluster_name" {
  type = string
}

variable "server_location" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "talos_schematic_id" {
  type = string
}

variable "talos_image_url" {
  type = string
}

variable "server_type" {
  type = string
}

# Source for the Talos AMD64 image
source "hcloud" "talos_amd64_image" {
  rescue       = "linux64"
  image        = "debian-13"
  location     = var.server_location
  server_type  = var.server_type
  ssh_username = "root"

  snapshot_name = "Talos Linux AMD64 for ${var.cluster_name}"
  snapshot_labels = {
    cluster            = var.cluster_name,
    os                 = "talos",
    talos_version      = var.talos_version,
    talos_schematic_id = substr(var.talos_schematic_id, 0, 32)
  }
}

# Build the Talos AMD64 snapshot
build {
  sources = ["source.hcloud.talos_amd64_image"]

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"

    inline = [
      <<-EOT
        set -euo pipefail

        printf '%s\n' 'Zeroing disk first before writing Talos image'
        blkdiscard -v /dev/sda 2>/dev/null

        printf '%s\n' 'Downloading Talos ${var.talos_version} (${var.talos_schematic_id}) ...'
        wget \
          --quiet \
          --timeout=20 \
          --waitretry=5 \
          --tries=5 \
          --retry-connrefused \
          --inet4-only \
          --output-document=- \
          '${var.talos_image_url}' \
        | xz -T0 -dc \
        | dd of=/dev/sda bs=1M iflag=fullblock oflag=direct conv=fsync status=none

        printf '%s\n' 'Talos ${var.talos_version} (${var.talos_schematic_id}) downloaded'
      EOT
    ]
  }
}
