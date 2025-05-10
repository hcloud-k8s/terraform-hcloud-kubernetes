variable "cluster_name" {
  type = string
}

variable "server_location" {
  type    = string
  default = "fsn1"
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

# Source for the Talos AMD64 image
source "hcloud" "amd64_builder" {
  rescue       = "linux64"
  image        = "debian-12"
  location     = var.server_location
  server_type  = "cpx11"
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
  sources = ["source.hcloud.amd64_builder"]

  provisioner "shell" {
    inline_shebang = "/bin/bash -e"

    inline = [
      <<-EOT
        set -euo pipefail

        # Discard the entire /dev/sda to free up space and make the snapshot smaller
        echo 'Zeroing disk first before writing Talos image'
        blkdiscard /dev/sda 2>/dev/null

        echo 'Download Talos ${var.talos_version} image (${var.talos_schematic_id})'

        wget \
          --quiet \
          --timeout=5 \
          --waitretry=5 \
          --tries=5 \
          --retry-connrefused \
          --inet4-only \
          --output-document=- \
          '${var.talos_image_url}' | \
        xz -d -c | dd status=none of=/dev/sda
        sync

        echo 'Talos ${var.talos_version} image (${var.talos_schematic_id}) downloaded'
      EOT
    ]
  }
}
