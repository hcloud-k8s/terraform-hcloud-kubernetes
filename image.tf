locals {
  talos_cloud_schematic_id = var.talos_schematic_id != null ? var.talos_schematic_id : talos_image_factory_schematic.cloud[0].id
  talos_metal_schematic_ids = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => talos_image_factory_schematic.metal[server_name].id
  }

  talos_cloud_installer_image_url = (
    local.cloud_amd64_image_required ? data.talos_image_factory_urls.cloud_amd64[0].urls.installer :
    local.cloud_arm64_image_required ? data.talos_image_factory_urls.cloud_arm64[0].urls.installer :
    null
  )
  talos_cloud_amd64_disk_image_url = local.cloud_amd64_image_required ? data.talos_image_factory_urls.cloud_amd64[0].urls.disk_image : null
  talos_cloud_arm64_disk_image_url = local.cloud_arm64_image_required ? data.talos_image_factory_urls.cloud_arm64[0].urls.disk_image : null
  talos_metal_disk_image_urls = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => data.talos_image_factory_urls.metal[server_name].urls.disk_image
  }
  talos_metal_installer_image_urls = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => data.talos_image_factory_urls.metal[server_name].urls.installer
  }

  cloud_arm64_server_type_pattern = "^cax\\d+$"

  cloud_amd64_image_required = anytrue([
    for np in concat(
      local.control_plane_nodepools,
      local.worker_nodepools,
      local.cluster_autoscaler_nodepools
    ) : !can(regex(local.cloud_arm64_server_type_pattern, np.server_type))
  ])
  cloud_arm64_image_required = anytrue([
    for np in concat(
      local.control_plane_nodepools,
      local.worker_nodepools,
      local.cluster_autoscaler_nodepools
    ) : can(regex(local.cloud_arm64_server_type_pattern, np.server_type))
  ])

  talos_image_label_selector = join(",",
    [
      "os=talos",
      "cluster=${var.cluster_name}",
      "talos_version=${var.talos_version}",
      "talos_schematic_id=${substr(local.talos_cloud_schematic_id, 0, 32)}"
    ]
  )

  # Version-agnostic selector for *consuming* the ARM64 snapshot (node boot and
  # cluster-autoscaler). It deliberately omits talos_version/schematic so node
  # creation always resolves to the newest existing cluster ARM64 snapshot, even
  # when a version bump means no version-matched snapshot exists yet (e.g. the
  # rebuild was skipped because Hetzner has no CAX capacity). The version-pinned
  # `talos_image_label_selector` above is kept for the build guard, which must
  # still detect "no snapshot for the current version -> build needed".
  talos_image_label_selector_arm64_any = join(",",
    [
      "os=talos",
      "cluster=${var.cluster_name}",
    ]
  )

  talos_image_extensions_longhorn = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]

  talos_image_extensions_base = distinct(
    concat(
      var.talos_image_extensions,
      var.longhorn_enabled ? local.talos_image_extensions_longhorn : []
    )
  )

  talos_cloud_image_extensions = distinct(
    concat(
      ["siderolabs/qemu-guest-agent"],
      local.talos_image_extensions_base
    )
  )

  talos_metal_image_extensions = local.talos_image_extensions_base
  talos_metal_image_common_extra_kernel_args = sort(distinct(
    concat(
      var.talos_extra_kernel_args,
      ["net.ifnames=0"]
    )
  ))

  talos_metal_extra_kernel_args = {
    for server_name, server in local.bare_metal_servers : server_name => distinct(
      concat(
        local.talos_metal_image_common_extra_kernel_args,
        var.cluster_access == "private" ? [
          "vlan=${local.bare_metal_vswitch_link_name}:${local.talos_public_link_name}",
          "ip=${server.private_ipv4}::${local.bare_metal_vswitch_ipv4_gateway}:${local.bare_metal_vswitch_ipv4_netmask}::${local.bare_metal_vswitch_link_name}:none",
        ] :
        ["ip=${local.bare_metal_server_public_network[server_name].server_ipv4}::${local.bare_metal_server_public_network[server_name].server_ipv4_gateway}:${cidrnetmask("0.0.0.0/${local.bare_metal_server_public_network[server_name].server_ipv4_mask}")}::${local.talos_public_link_name}:none"],
        local.bare_metal_public_ipv6_enabled[server_name] ? [
          "ip=[${local.bare_metal_public_ipv6_addresses[server_name]}]::[fe80::1]:64::${local.talos_public_link_name}:none"
        ] : []
      )
    )
  }
}

data "talos_image_factory_extensions_versions" "cloud" {
  count = var.talos_schematic_id == null ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = local.talos_cloud_image_extensions
  }
}

data "talos_image_factory_extensions_versions" "metal" {
  count = local.bare_metal_enabled && length(local.talos_metal_image_extensions) > 0 ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = local.talos_metal_image_extensions
  }
}

resource "talos_image_factory_schematic" "cloud" {
  count = var.talos_schematic_id == null ? 1 : 0

  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = var.talos_extra_kernel_args
        systemExtensions = {
          officialExtensions = (
            length(local.talos_cloud_image_extensions) > 0 ?
            data.talos_image_factory_extensions_versions.cloud[0].extensions_info.*.name :
            []
          )
        }
      }
    }
  )
}

resource "talos_image_factory_schematic" "metal" {
  for_each = local.bare_metal_servers

  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = local.talos_metal_extra_kernel_args[each.key]
        systemExtensions = {
          officialExtensions = (
            length(local.talos_metal_image_extensions) > 0 ?
            data.talos_image_factory_extensions_versions.metal[0].extensions_info.*.name :
            []
          )
        }
      }
    }
  )
}

data "talos_image_factory_urls" "cloud_amd64" {
  count = local.cloud_amd64_image_required ? 1 : 0

  talos_version = var.talos_version
  schematic_id  = local.talos_cloud_schematic_id
  platform      = "hcloud"
  architecture  = "amd64"
}

data "talos_image_factory_urls" "cloud_arm64" {
  count = local.cloud_arm64_image_required ? 1 : 0

  talos_version = var.talos_version
  schematic_id  = local.talos_cloud_schematic_id
  platform      = "hcloud"
  architecture  = "arm64"
}

data "talos_image_factory_urls" "metal" {
  for_each = local.bare_metal_servers

  talos_version = var.talos_version
  schematic_id  = local.talos_metal_schematic_ids[each.key]
  platform      = "metal"
  architecture  = each.value.architecture
}

data "hcloud_images" "amd64" {
  count = local.cloud_amd64_image_required ? 1 : 0

  with_selector     = local.talos_image_label_selector
  with_architecture = ["x86"]
  most_recent       = true
}

data "hcloud_images" "arm64" {
  count = local.cloud_arm64_image_required ? 1 : 0

  with_selector     = local.talos_image_label_selector
  with_architecture = ["arm"]
  most_recent       = true
}

resource "terraform_data" "packer_init" {
  triggers_replace = [
    "${sha1(file("${path.module}/packer/requirements.pkr.hcl"))}",
    var.cluster_name,
    var.talos_version,
    local.talos_cloud_schematic_id,
    local.cloud_amd64_image_required,
    local.cloud_arm64_image_required
  ]

  provisioner "local-exec" {
    when        = create
    quiet       = true
    working_dir = "${path.module}/packer/"
    command     = "packer init -upgrade requirements.pkr.hcl"
  }

  depends_on = [data.external.client_prerequisites_check]
}

resource "terraform_data" "amd64_image" {
  count = local.cloud_amd64_image_required ? 1 : 0

  triggers_replace = [
    var.cluster_name,
    var.talos_version,
    local.talos_cloud_schematic_id
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
        "-var 'server_type=${var.packer_amd64_builder.server_type}'",
        "-var 'server_location=${var.packer_amd64_builder.server_location}'",
        "-var 'talos_version=${var.talos_version}'",
        "-var 'talos_schematic_id=${local.talos_cloud_schematic_id}'",
        "-var 'talos_image_url=${local.talos_cloud_amd64_disk_image_url}'",
        "image_amd64.pkr.hcl"
      ]
    )
    environment = {
      HCLOUD_TOKEN = nonsensitive(var.hcloud_token)
    }
  }

  depends_on = [
    data.external.client_prerequisites_check,
    terraform_data.packer_init
  ]
}

resource "terraform_data" "arm64_image" {
  count = local.cloud_arm64_image_required ? 1 : 0

  triggers_replace = [
    var.cluster_name,
    var.talos_version,
    local.talos_cloud_schematic_id
  ]

  provisioner "local-exec" {
    when        = create
    quiet       = true
    working_dir = "${path.module}/packer/"
    command = join(" ",
      [
        "${length(data.hcloud_images.arm64[0].images) > 0} ||",
        "bash build_softfail.sh -force",
        "-var 'cluster_name=${var.cluster_name}'",
        "-var 'server_type=${var.packer_arm64_builder.server_type}'",
        "-var 'server_location=${var.packer_arm64_builder.server_location}'",
        "-var 'talos_version=${var.talos_version}'",
        "-var 'talos_schematic_id=${local.talos_cloud_schematic_id}'",
        "-var 'talos_image_url=${local.talos_cloud_arm64_disk_image_url}'",
        "image_arm64.pkr.hcl"
      ]
    )
    environment = {
      HCLOUD_TOKEN = nonsensitive(var.hcloud_token)
    }
  }

  depends_on = [
    data.external.client_prerequisites_check,
    terraform_data.packer_init
  ]
}

data "hcloud_image" "amd64" {
  count = local.cloud_amd64_image_required ? 1 : 0

  with_selector     = local.talos_image_label_selector
  with_architecture = "x86"
  most_recent       = true

  depends_on = [terraform_data.amd64_image]
}

data "hcloud_image" "arm64" {
  count = local.cloud_arm64_image_required ? 1 : 0

  with_selector     = local.talos_image_label_selector_arm64_any
  with_architecture = "arm"
  most_recent       = true

  depends_on = [terraform_data.arm64_image]
}
