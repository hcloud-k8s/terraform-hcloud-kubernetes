locals {
  talos_schematic_id = coalesce(var.talos_schematic_id, talos_image_factory_schematic.this[0].id)

  talos_installer_image_url = data.talos_image_factory_urls.amd64.urls.installer
  talos_amd64_image_url     = data.talos_image_factory_urls.amd64.urls.disk_image
  talos_arm64_image_url     = data.talos_image_factory_urls.arm64.urls.disk_image

  amd64_image_required = anytrue([
    for np in concat(
      local.control_plane_nodepools,
      local.worker_nodepools,
      local.cluster_autoscaler_nodepools
    ) : substr(np.server_type, 0, 3) != "cax"
  ])
  arm64_image_required = anytrue([
    for np in concat(
      local.control_plane_nodepools,
      local.worker_nodepools,
      local.cluster_autoscaler_nodepools
    ) : substr(np.server_type, 0, 3) == "cax"
  ])

  image_label_selector = join(",",
    [
      "os=talos",
      "cluster=${var.cluster_name}",
      "talos_version=${var.talos_version}",
      "talos_schematic_id=${substr(local.talos_schematic_id, 0, 32)}"
    ]
  )

  talos_image_extentions_longhorn = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]

  talos_image_extensions = distinct(
    concat(
      ["siderolabs/qemu-guest-agent"],
      var.talos_image_extensions,
      var.longhorn_enabled ? local.talos_image_extentions_longhorn : []
    )
  )
}

data "talos_image_factory_extensions_versions" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = local.talos_image_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = var.talos_extra_kernel_args
        systemExtensions = {
          officialExtensions = (
            length(local.talos_image_extensions) > 0 ?
            data.talos_image_factory_extensions_versions.this[0].extensions_info.*.name :
            []
          )
        }
      }
    }
  )
}

data "talos_image_factory_urls" "amd64" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "hcloud"
  architecture  = "amd64"
}

data "talos_image_factory_urls" "arm64" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "hcloud"
  architecture  = "arm64"
}

data "hcloud_image" "amd64" {
  count = local.amd64_image_required ? 1 : 0

  with_selector     = local.image_label_selector
  with_architecture = "x86"
  most_recent       = true

  depends_on = [terraform_data.amd64_image]
}

data "hcloud_image" "arm64" {
  count = local.arm64_image_required ? 1 : 0

  with_selector     = local.image_label_selector
  with_architecture = "arm"
  most_recent       = true

  depends_on = [terraform_data.arm64_image]
}

data "hcloud_images" "amd64" {
  count = local.amd64_image_required ? 1 : 0

  with_selector     = local.image_label_selector
  with_architecture = ["x86"]
  most_recent       = true
}

data "hcloud_images" "arm64" {
  count = local.arm64_image_required ? 1 : 0

  with_selector     = local.image_label_selector
  with_architecture = ["arm"]
  most_recent       = true
}

resource "terraform_data" "packer_init" {
  triggers_replace = ["${sha1(file("${path.module}/packer/requirements.pkr.hcl"))}"]

  provisioner "local-exec" {
    when        = create
    quiet       = true
    working_dir = "${path.module}/packer/"
    command     = "packer init -upgrade requirements.pkr.hcl"
  }
}

resource "terraform_data" "amd64_image" {
  count = local.amd64_image_required ? 1 : 0

  triggers_replace = [
    var.cluster_name,
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when        = create
    quiet       = true
    working_dir = "${path.module}/packer/"
    command = join(" ",
      [
        "${length(data.hcloud_images.amd64[0].images) > 0} ||",
        "packer build -force",
        "-var 'cluster_name=${var.cluster_name}'",
        "-var 'talos_version=${var.talos_version}'",
        "-var 'talos_schematic_id=${local.talos_schematic_id}'",
        "-var 'talos_image_url=${local.talos_amd64_image_url}'",
        "image_amd64.pkr.hcl"
      ]
    )
    environment = {
      HCLOUD_TOKEN = nonsensitive(var.hcloud_token)
    }
  }

  depends_on = [terraform_data.packer_init]
}

resource "terraform_data" "arm64_image" {
  count = local.arm64_image_required ? 1 : 0

  triggers_replace = [
    var.cluster_name,
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when        = create
    quiet       = true
    working_dir = "${path.module}/packer/"
    command = join(" ",
      [
        "${length(data.hcloud_images.arm64[0].images) > 0} ||",
        "packer build -force",
        "-var 'cluster_name=${var.cluster_name}'",
        "-var 'talos_version=${var.talos_version}'",
        "-var 'talos_schematic_id=${local.talos_schematic_id}'",
        "-var 'talos_image_url=${local.talos_arm64_image_url}'",
        "image_arm64.pkr.hcl"
      ]
    )
    environment = {
      HCLOUD_TOKEN = nonsensitive(var.hcloud_token)
    }
  }

  depends_on = [terraform_data.packer_init]
}
