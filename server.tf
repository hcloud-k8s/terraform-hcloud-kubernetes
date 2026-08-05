locals {
  bare_metal_servers = length(local.bare_metal_nodepools) > 0 ? merge([
    for np in local.bare_metal_nodepools : {
      for server in np.servers : "${var.cluster_name}-${np.name}-${server.number}" => {
        nodepool     = np.name,
        name         = "${var.cluster_name}-${np.name}-${server.number}",
        architecture = np.architecture,
        number       = server.number,
        private_ipv4 = server.private_ipv4,
        install_disk = server.install_disk,
        raid_mode    = np.raid_mode,
      }
    }
  ]...) : {}
}

resource "hcloud_server" "control_plane" {
  for_each = merge([
    for np_index in range(length(local.control_plane_nodepools)) : {
      for cp_index in range(local.control_plane_nodepools[np_index].count) : "${var.cluster_name}-${local.control_plane_nodepools[np_index].name}-${cp_index + 1}" => {
        server_type        = local.control_plane_nodepools[np_index].server_type,
        location           = local.control_plane_nodepools[np_index].location,
        backups            = local.control_plane_nodepools[np_index].backups,
        keep_disk          = local.control_plane_nodepools[np_index].keep_disk,
        labels             = local.control_plane_nodepools[np_index].labels,
        placement_group_id = hcloud_placement_group.control_plane.id,
        subnet_id          = hcloud_network_subnet.control_plane.id,
      }
    }
  ]...)

  name                     = each.key
  image                    = can(regex(local.cloud_arm64_server_type_pattern, each.value.server_type)) ? data.hcloud_image.arm64[0].id : data.hcloud_image.amd64[0].id
  server_type              = each.value.server_type
  location                 = each.value.location
  placement_group_id       = each.value.placement_group_id
  backups                  = each.value.backups
  keep_disk                = each.value.keep_disk
  ssh_keys                 = [hcloud_ssh_key.this.id]
  shutdown_before_deletion = true
  user_data                = local.talos_user_data
  delete_protection        = var.cluster_delete_protection
  rebuild_protection       = var.cluster_delete_protection

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "control-plane"
    }
  )

  firewall_ids = [local.firewall_id]

  public_net {
    ipv4_enabled = var.talos_public_ipv4_enabled
    ipv6_enabled = var.talos_public_ipv6_enabled
  }

  network {
    subnet_id = each.value.subnet_id
    alias_ips = []
  }

  depends_on = [
    terraform_data.hcloud_server_cluster_autoscaler,
    hcloud_network_subnet.control_plane,
    hcloud_placement_group.control_plane
  ]

  lifecycle {
    ignore_changes = [
      image,
      user_data,
      network,
      ssh_keys
    ]
  }
}

resource "hcloud_server" "worker" {
  for_each = merge([
    for np_index in range(length(local.worker_nodepools)) : {
      for wkr_index in range(local.worker_nodepools[np_index].count) : "${var.cluster_name}-${local.worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        server_type        = local.worker_nodepools[np_index].server_type,
        location           = local.worker_nodepools[np_index].location,
        backups            = local.worker_nodepools[np_index].backups,
        keep_disk          = local.worker_nodepools[np_index].keep_disk,
        labels             = local.worker_nodepools[np_index].labels,
        placement_group_id = local.worker_nodepools[np_index].placement_group ? hcloud_placement_group.worker["${var.cluster_name}-${local.worker_nodepools[np_index].name}-pg-${ceil((wkr_index + 1) / 10.0)}"].id : null,
        subnet_id          = local.worker_nodepools[np_index].subnet != null ? hcloud_network_subnet.worker[local.worker_nodepools[np_index].name].id : hcloud_network_subnet.worker_shared.id,
        ipv4_private       = local.worker_nodepools[np_index].subnet != null ? cidrhost(hcloud_network_subnet.worker[local.worker_nodepools[np_index].name].ip_range, wkr_index + 1) : null,
      }
    }
  ]...)

  name                     = each.key
  image                    = can(regex(local.cloud_arm64_server_type_pattern, each.value.server_type)) ? data.hcloud_image.arm64[0].id : data.hcloud_image.amd64[0].id
  server_type              = each.value.server_type
  location                 = each.value.location
  placement_group_id       = each.value.placement_group_id
  backups                  = each.value.backups
  keep_disk                = each.value.keep_disk
  ssh_keys                 = [hcloud_ssh_key.this.id]
  shutdown_before_deletion = true
  user_data                = local.talos_user_data
  delete_protection        = var.cluster_delete_protection
  rebuild_protection       = var.cluster_delete_protection

  labels = merge(
    each.value.labels,
    {
      cluster = var.cluster_name,
      role    = "worker"
    }
  )

  firewall_ids = [local.firewall_id]

  public_net {
    ipv4_enabled = var.talos_public_ipv4_enabled
    ipv6_enabled = var.talos_public_ipv6_enabled
  }

  network {
    subnet_id = each.value.subnet_id
    ip        = each.value.ipv4_private
    alias_ips = []
  }

  depends_on = [
    terraform_data.hcloud_server_cluster_autoscaler,
    hcloud_network_subnet.worker_shared,
    hcloud_network_subnet.worker,
    hcloud_placement_group.worker
  ]

  lifecycle {
    ignore_changes = [
      image,
      user_data,
      ssh_keys
    ]
  }
}

data "external" "bare_metal_server" {
  for_each = local.bare_metal_enabled ? local.bare_metal_servers : {}

  program = [
    "sh", "-c", <<-EOT
      set -eu

      input=$(cat)
      robot_api_url=$(printf '%s' "$input" | jq -r '.robot_api_url')
      robot_user=$(printf '%s' "$input" | jq -r '.robot_user')
      robot_password=$(printf '%s' "$input" | jq -r '.robot_password')
      server_number=$(printf '%s' "$input" | jq -r '.server_number')

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$robot_user:$robot_password" \
        "$robot_api_url/server/$server_number" || true)

      case "$status" in
        200)
          ;;
        *)
          printf 'Unexpected Robot API status while looking up bare metal server %s: %s\n' "$server_number" "$status" >&2
          exit 1
          ;;
      esac

      server_ipv4=$(jq -r '.server.server_ip // ""' "$response_file")
      server_ipv6_net=$(jq -r '.server.server_ipv6_net // ""' "$response_file")
      rescue_supported=$(jq -r '.server.rescue // false' "$response_file")
      reset_supported=$(jq -r '.server.reset // false' "$response_file")

      if [ -z "$server_ipv4" ]; then
        printf 'Could not determine public IP for bare metal server %s\n' "$server_number" >&2
        exit 1
      fi

      if [ "$server_ipv6_net" = "null" ]; then
        server_ipv6_net=""
      fi

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$robot_user:$robot_password" \
        "$robot_api_url/ip/$server_ipv4" || true)

      case "$status" in
        200)
          ;;
        *)
          printf 'Unexpected Robot API status while looking up public IP %s for bare metal server %s: %s\n' "$server_ipv4" "$server_number" "$status" >&2
          exit 1
          ;;
      esac

      server_ipv4_gateway=$(jq -r '.ip.gateway // ""' "$response_file")
      server_ipv4_mask=$(jq -r '.ip.mask // ""' "$response_file")

      if [ -z "$server_ipv4_gateway" ] || [ -z "$server_ipv4_mask" ]; then
        printf 'Could not determine public IP gateway or mask for bare metal server %s\n' "$server_number" >&2
        exit 1
      fi

      jq -n \
        --arg server_ipv4 "$server_ipv4" \
        --arg server_ipv4_gateway "$server_ipv4_gateway" \
        --arg server_ipv4_mask "$server_ipv4_mask" \
        --arg server_ipv6_net "$server_ipv6_net" \
        --arg rescue_supported "$rescue_supported" \
        --arg reset_supported "$reset_supported" \
        '{server_ipv4: $server_ipv4, server_ipv4_gateway: $server_ipv4_gateway, server_ipv4_mask: $server_ipv4_mask, server_ipv6_net: $server_ipv6_net, rescue_supported: $rescue_supported, reset_supported: $reset_supported}'
    EOT
  ]

  query = {
    robot_api_url  = var.hcloud_robot_api_url
    robot_user     = var.hcloud_robot_user
    robot_password = var.hcloud_robot_password
    server_number  = tostring(each.value.number)
  }
}

locals {
  bare_metal_server_public_network = {
    for server_name in keys(local.bare_metal_servers) :
    server_name => nonsensitive(data.external.bare_metal_server[server_name].result)
  }

  bare_metal_initialization_ssh_hosts = {
    for server_name in keys(local.bare_metal_servers) : server_name => (
      local.bare_metal_initialization_firewall_ipv6_enabled ? (
        try(cidrhost("${local.bare_metal_server_public_network[server_name].server_ipv6_net}/64", 2), "")
      ) :
      local.bare_metal_server_public_network[server_name].server_ipv4
    )
  }
}

resource "terraform_data" "bare_metal_server_name" {
  for_each = local.bare_metal_enabled ? local.bare_metal_servers : {}

  triggers_replace = {
    name          = each.value.name
    server_number = each.value.number
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Setting Robot name for bare metal server %s to %s\n' "${self.triggers_replace.server_number}" "${self.triggers_replace.name}"

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        --data-urlencode "server_name=${self.triggers_replace.name}" \
        "${var.hcloud_robot_api_url}/server/${self.triggers_replace.server_number}" || true)

      case "$status" in
        200)
          ;;
        *)
          printf 'Unexpected Robot API status while setting name for bare metal server %s: %s\n' "${self.triggers_replace.server_number}" "$status" >&2
          cat "$response_file" >&2
          exit 1
          ;;
      esac

      printf 'Robot name set for bare metal server %s\n' "${self.triggers_replace.server_number}"
    EOT

    environment = {
      ROBOT_USER     = var.hcloud_robot_user
      ROBOT_PASSWORD = nonsensitive(var.hcloud_robot_password)
    }
  }
}

resource "terraform_data" "bare_metal_server" {
  for_each = local.bare_metal_enabled ? local.bare_metal_servers : {}

  lifecycle {
    precondition {
      condition     = local.bare_metal_server_public_network[each.key].rescue_supported == "true"
      error_message = "Bare metal server ${each.value.number} does not support rescue mode."
    }

    precondition {
      condition     = local.bare_metal_server_public_network[each.key].reset_supported == "true"
      error_message = "Bare metal server ${each.value.number} does not support reset."
    }

    precondition {
      condition     = local.bare_metal_initialization_ssh_hosts[each.key] != ""
      error_message = "Bare metal initialization SSH host could not be determined for server ${each.value.number}."
    }
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Enabling rescue mode for bare metal server %s\n' "${each.value.number}"

      status=$(curl -sS -o /dev/null -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        --data-urlencode "os=linux" \
        --data-urlencode "authorized_key[]=${tls_private_key.ssh_key.public_key_fingerprint_md5}" \
        "${var.hcloud_robot_api_url}/boot/${each.value.number}/rescue" || true)

      case "$status" in
        200|201)
          ;;
        *)
          printf 'Unexpected Robot API status while enabling rescue mode for server %s: %s\n' "${each.value.number}" "$status" >&2
          exit 1
          ;;
      esac

      printf 'Resetting bare metal server %s to boot into rescue mode\n' "${each.value.number}"

      status=$(curl -sS -o /dev/null -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        --data-urlencode "type=hw" \
        "${var.hcloud_robot_api_url}/reset/${each.value.number}" || true)

      case "$status" in
        200|201)
          ;;
        *)
          printf 'Unexpected Robot API status while resetting server %s: %s\n' "${each.value.number}" "$status" >&2
          exit 1
          ;;
      esac

      printf 'Bare metal server %s rescue boot requested\n' "${each.value.number}"
    EOT

    environment = {
      ROBOT_USER     = var.hcloud_robot_user
      ROBOT_PASSWORD = nonsensitive(var.hcloud_robot_password)
    }
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Opening Robot firewall for bare metal server %s\n' "${each.value.number}"

      response_file=$(mktemp)
      curl_config=$(mktemp)
      cleanup() { rm -f "$response_file" "$curl_config"; }
      trap 'cleanup' EXIT

      printf '%s' "$ROBOT_FIREWALL_CURL_DATA" | jq -r '.[] | "data-urlencode = " + (. | @json)' > "$curl_config"

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          --config "$curl_config" \
          "${var.hcloud_robot_api_url}/firewall/${each.value.number}" || true)

        case "$status" in
          200|201|202)
            break
            ;;
          409)
            printf 'Robot firewall update for server %s is still in process, retrying (%s/100)\n' "${each.value.number}" "$attempt"
            sleep 10
            ;;
          *)
            printf 'Unexpected Robot API status while opening firewall for server %s: %s\n' "${each.value.number}" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      if [ "$status" != "200" ] && [ "$status" != "201" ] && [ "$status" != "202" ]; then
        printf 'Robot firewall update for server %s did not complete after retries, last status: %s\n' "${each.value.number}" "$status" >&2
        exit 1
      fi

      printf 'Waiting 60 seconds for Robot firewall update to apply on server %s\n' "${each.value.number}"
      sleep 60

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "${var.hcloud_robot_api_url}/firewall/${each.value.number}" || true)

        case "$status" in
          200)
            firewall_status=$(jq -r '.firewall.status // empty' "$response_file")

            case "$firewall_status" in
              active)
                break
                ;;
              "in process")
                printf 'Robot firewall for server %s is still in process, waiting (%s/100)\n' "${each.value.number}" "$attempt"
                sleep 10
                ;;
              *)
                printf 'Unexpected Robot firewall status for server %s: %s\n' "${each.value.number}" "$firewall_status" >&2
                exit 1
                ;;
            esac
            ;;
          *)
            printf 'Unexpected Robot API status while checking firewall for server %s: %s\n' "${each.value.number}" "$status" >&2
            exit 1
            ;;
        esac
      done

      if [ "$firewall_status" != "active" ]; then
        printf 'Robot firewall for server %s did not become active after retries, last status: %s\n' "${each.value.number}" "$firewall_status" >&2
        exit 1
      fi

      printf 'Robot firewall opened for bare metal server %s\n' "${each.value.number}"
    EOT

    environment = {
      ROBOT_FIREWALL_CURL_DATA = jsonencode(local.bare_metal_initialization_firewall_curl_data)
      ROBOT_USER               = var.hcloud_robot_user
      ROBOT_PASSWORD           = nonsensitive(var.hcloud_robot_password)
    }
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
      bash <<'SCRIPT'
      set -euo pipefail

      for command in blkdiscard blockdev cat dd find grep head lsblk mdadm partprobe readlink sed sgdisk shutdown sort sync udevadm wget wipefs zstd; do
        if ! command -v "$command" >/dev/null 2>&1; then
          printf 'ERROR: required command not found: %s\n' "$command" >&2
          exit 1
        fi
      done

      has_mounts_below() {
        lsblk -nr -o MOUNTPOINTS "$1" 2>/dev/null | grep -q '[^[:space:]]'
      }

      lsblk_field() {
        lsblk -dn -o "$2" "$1" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'
      }

      first_link() {
        dir="$1"
        dev="$2"

        find -L "$dir" -samefile "$dev" ! -name '*-part*' -printf '%p\n' 2>/dev/null | sort | head -n1 || true
      }

      get_install_disks() {
        udevadm settle

        find /sys/block/ \
          \( -name 'nvme[0-9]*n[0-9]' -o -name '[hvs]d[a-z]' -o -name 'xvd[a-z]' \) \
          -printf '%f\n' \
        | sort \
        | while read -r name; do
            dev="/dev/$name"

            [ -b "$dev" ] || continue
            [ "$(cat "/sys/block/$name/removable" 2>/dev/null)" = "0" ] || continue
            [ "$(cat "/sys/block/$name/ro" 2>/dev/null)" = "0" ] || continue
            [ "$(lsblk_field "$dev" TYPE)" = "disk" ] || continue
            [ "$(lsblk_field "$dev" TRAN)" != "usb" ] || continue

            if has_mounts_below "$dev"; then
              printf 'skip disk=%s reason=mounted\n' "$dev" >&2
              continue
            fi

            printf '%s\n' "$dev"
          done
      }

      print_disk() {
        role="$1"
        dev="$2"

        printf '%s disk=%s size="%s" model="%s" serial="%s" wwn="%s" tran="%s" by_id="%s" by_path="%s"\n' \
          "$role" \
          "$dev" \
          "$(lsblk_field "$dev" SIZE)" \
          "$(lsblk_field "$dev" MODEL)" \
          "$(lsblk_field "$dev" SERIAL)" \
          "$(lsblk_field "$dev" WWN)" \
          "$(lsblk_field "$dev" TRAN)" \
          "$(first_link /dev/disk/by-id "$dev")" \
          "$(first_link /dev/disk/by-path "$dev")"
      }

      wipe_disk() {
        disk="$1"

        if has_mounts_below "$disk"; then
          printf 'ERROR: refusing to wipe mounted disk=%s\n' "$disk" >&2
          exit 1
        fi

        printf 'wipe disk=%s\n' "$disk"

        wipefs --all --force "$disk" >/dev/null 2>&1
        sgdisk --zap-all "$disk" >/dev/null 2>&1
        blkdiscard -f "$disk" >/dev/null 2>&1 || true

        dd if=/dev/zero of="$disk" bs=1M count=32 conv=fsync status=none

        size_bytes="$(blockdev --getsize64 "$disk" 2>/dev/null || printf '0')"
        if [ "$size_bytes" -gt $((64 * 1024 * 1024)) ]; then
          seek_mib=$((size_bytes / 1024 / 1024 - 32))
          dd if=/dev/zero of="$disk" bs=1M seek="$seek_mib" count=32 conv=fsync status=none
        fi

        partprobe "$disk" >/dev/null 2>&1 || blockdev --rereadpt "$disk" >/dev/null 2>&1
        sync
      }

      configured_install_disk_id='${each.value.install_disk != null ? each.value.install_disk : ""}'
      raid_mode='${each.value.raid_mode}'
      mapfile -t install_disks < <(get_install_disks)

      if [ "$${#install_disks[@]}" -eq 0 ]; then
        printf '%s\n' 'ERROR: Could not detect install disk' >&2
        exit 1
      fi

      if [ -n "$configured_install_disk_id" ]; then
        case "$configured_install_disk_id" in
          */*)
            printf 'ERROR: install_disk must be a disk ID from /dev/disk/by-id, got %s\n' "$configured_install_disk_id" >&2
            exit 1
            ;;
        esac

        install_disk="$(readlink -f "/dev/disk/by-id/$configured_install_disk_id" 2>/dev/null || true)"
        if [ -z "$install_disk" ]; then
          printf 'ERROR: configured install_disk was not found in /dev/disk/by-id: %s\n' "$configured_install_disk_id" >&2
          exit 1
        fi
      else
        install_disk="$${install_disks[0]}"
      fi

      if [ -z "$install_disk" ] || [ ! -b "$install_disk" ]; then
        printf '%s\n' 'ERROR: Could not detect install disk' >&2
        exit 1
      fi

      if ! printf '%s\n' "$${install_disks[@]}" | grep -Fxq "$install_disk"; then
        printf 'ERROR: configured install disk is not an eligible install disk: %s\n' "$install_disk" >&2
        exit 1
      fi

      # ============================================================
      # RAID 1 support: write Talos to all physical disks so the
      # system can boot from any disk. The EPHEMERAL partition
      # (where container data lives) is created by Talos on first
      # boot, so we can't create a RAID array during provisioning.
      #
      # Data redundancy is provided by:
      # 1. Boot redundancy: bootloader on all physical disks
      # 2. Application replication: Mimir RF=2, Kafka RF=3 across nodes
      #
      # For RAID 1 of the EPHEMERAL partition, configure it post-boot
      # via Talos machine config patches (mdadm assemble + mount).
      # ============================================================
      raid_device=""
      if [ "$raid_mode" = "raid1" ] && [ "$${#install_disks[@]}" -ge 2 ]; then
        printf 'RAID 1: writing Talos to %s disks for boot redundancy\n' "$${#install_disks[@]}"

        # Stop any existing RAID arrays on these disks
        mdadm --stop /dev/md0 2>/dev/null || true
        mdadm --stop /dev/md127 2>/dev/null || true
        # Remove stale superblocks from previous RAID attempts
        for disk in "$${install_disks[@]}"; do
          mdadm --zero-superblock "$disk" 2>/dev/null || true
        done

        # Wipe all disks
        for disk in "$${install_disks[@]}"; do
          wipe_disk "$disk"
        done
        udevadm settle
        sleep 2

        # Write Talos image to ALL physical disks (bootloader on each)
        for disk in "$${install_disks[@]}"; do
          printf 'RAID 1: writing Talos to %s\n' "$disk"
          wget \
            --quiet \
            --timeout=20 \
            --waitretry=5 \
            --tries=5 \
            --retry-connrefused \
            --inet4-only \
            --output-document=- \
            "${local.talos_metal_disk_image_urls[each.key]}" \
          | zstd -dc \
          | dd of="$disk" bs=1M iflag=fullblock oflag=direct conv=fsync status=none
          sync
          partprobe "$disk" >/dev/null 2>&1 || blockdev --rereadpt "$disk" >/dev/null 2>&1
          udevadm settle
        done

        for disk in "$${install_disks[@]}"; do
          print_disk "raid-boot" "$disk"
        done
        printf 'RAID 1: boot redundancy enabled (Talos on all disks)\n'

        # Skip the single-disk write below — we already wrote to all disks
        skip_write=true
      else
        # No RAID — original single-disk flow
        skip_write=false
        for disk in "$${install_disks[@]}"; do
          if [ "$disk" = "$install_disk" ]; then
            print_disk "select" "$disk"
          else
            print_disk "deboot" "$disk"
          fi
        done

        for disk in "$${install_disks[@]}"; do
          [ "$disk" != "$install_disk" ] || continue
          wipe_disk "$disk"
        done

        wipe_disk "$install_disk"
      fi

      if [ "$skip_write" != "true" ]; then
        printf 'write disk=%s talos=%s schematic=%s\n' \
          "$install_disk" \
          '${var.talos_version}' \
          '${local.talos_metal_schematic_ids[each.key]}'

        wget \
          --quiet \
          --timeout=20 \
          --waitretry=5 \
          --tries=5 \
          --retry-connrefused \
          --inet4-only \
          --output-document=- \
          "${local.talos_metal_disk_image_urls[each.key]}" \
        | zstd -dc \
        | dd of="$install_disk" bs=1M iflag=fullblock oflag=direct conv=fsync status=none

        sync
      fi

      printf 'done disk=%s talos=%s\n' "$install_disk" '${var.talos_version}'
      printf '%s\n' 'reboot scheduled'

      shutdown -r +1
      SCRIPT
    EOT
    ]

    connection {
      type        = "ssh"
      host        = local.bare_metal_initialization_ssh_hosts[each.key]
      user        = "root"
      private_key = tls_private_key.ssh_key.private_key_openssh
      timeout     = "15m"
    }
  }

  depends_on = [
    terraform_data.bare_metal_server_name,
    terraform_data.robot_ssh_key
  ]
}

resource "terraform_data" "hcloud_server_cluster_autoscaler" {
  triggers_replace = {
    hcloud_api_token = var.hcloud_token
  }

  input = {
    hcloud_api_url      = "https://api.hetzner.cloud/v1"
    cleanup_enabled     = var.cluster_autoscaler_cleanup_enabled
    node_label_selector = local.cluster_autoscaler_node_label_selector
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<-EOT
      set -eu

      if [ "${self.input.cleanup_enabled}" != "true" ] || [ -z "${self.input.node_label_selector}" ]; then
        exit 0
      fi

      tab=$(printf '\011')

      hcloud_api() {
        curl -sSf \
          -H "Authorization: Bearer $HCLOUD_TOKEN" \
          --connect-timeout 10 \
          --retry 5 \
          --retry-all-errors \
          --retry-delay 10 \
          "$@"
      }

      nodes=$(
        page=1
        while :; do
          response=$(
            hcloud_api \
              --get "${self.input.hcloud_api_url}/servers" \
              --data-urlencode "per_page=50" \
              --data-urlencode "page=$page" \
              --data-urlencode "label_selector=${self.input.node_label_selector}"
          )
          printf '%s\n' "$response" | jq -c '.servers[] | {id,name}'

          next_page=$(printf '%s\n' "$response" | jq -r '.meta.pagination.next_page')
          if [ "$next_page" = "null" ]; then
            break
          fi

          page=$next_page
        done | jq -rs 'unique_by(.id)[] | "\(.id)\t\(.name)"'
      )

      if [ -n "$nodes" ]; then
        printf '%s\n' "$nodes" | while IFS="$tab" read -r id name; do
          printf 'Deleting %s (%s)\n' "$name" "$id"
          hcloud_api -X DELETE "${self.input.hcloud_api_url}/servers/$id" >/dev/null
        done
      fi
    EOT

    environment = {
      HCLOUD_TOKEN = nonsensitive(self.triggers_replace.hcloud_api_token)
    }
  }

  depends_on = [
    hcloud_network_subnet.autoscaler,
    hcloud_network_subnet.cluster_autoscaler,
    hcloud_network_subnet.cluster_autoscaler_shared,
  ]
}

locals {
  # IPv4 private (RFC1918)
  ipv4_private_pattern = "^(10\\.|192\\.168\\.|172\\.(1[6-9]|2\\d|3[0-1])\\.)"

  # IPv4 special or non-public
  # 0/8, 127/8, 169.254/16, 100.64/10, 192.0.0/24, 192.0.2/24, 192.88.99/24,
  # 198.18/15, 198.51.100/24, 203.0.113/24, 224/4 multicast, 240/4 reserved
  ipv4_special_pattern = "^(0\\.|127\\.|169\\.254\\.|100\\.(6[4-9]|[7-9]\\d|1[01]\\d|12[0-7])\\.|192\\.0\\.0\\.|192\\.0\\.2\\.|192\\.88\\.99\\.|198\\.(1[8-9])\\.|198\\.51\\.100\\.|203\\.0\\.113\\.|22[4-9]\\.|23\\d\\.|24\\d\\.|25[0-5]\\.)"

  # IPv6 private (ULA only: fc00::/7)
  ipv6_private_pattern = "^f[cd][0-9a-f]{2}:"

  # IPv6 non-public or special
  # ::, ::1, link-local fe80::/10 (fe80..febf), unique local fc00::/7, multicast ff00::/8,
  # documentation 2001:db8::/32, IPv4-mapped ::ffff:0:0/96
  ipv6_non_public_pattern = "^(::$|::1$|fe[89ab][0-9a-f]:|f[cd][0-9a-f]*:|ff[0-9a-f]*:|2001:db8:|::ffff:)"

  talos_discovery_cluster_autoscaler = var.cluster_autoscaler_discovery_enabled ? {
    for m in jsondecode(try(data.external.talos_member[0].result.cluster_autoscaler, "[]")) : m.spec.hostname => {
      nodepool = regex(local.cluster_autoscaler_hostname_pattern, m.spec.hostname)[0]

      private_ipv4_address = try(
        [
          for a in m.spec.addresses : a
          if can(cidrnetmask("${a}/32"))
          && can(regex(local.ipv4_private_pattern, a))
        ][0], null
      )
      public_ipv4_address = try(
        [
          for a in m.spec.addresses : a
          if can(cidrnetmask("${a}/32"))
          && !can(regex(local.ipv4_private_pattern, a))
          && !can(regex(local.ipv4_special_pattern, a))
        ][0], null
      )
      private_ipv6_address = try(
        [
          for a in m.spec.addresses : lower(a)
          if can(cidrsubnet("${a}/128", 0, 0))
          && can(regex(local.ipv6_private_pattern, lower(a)))
        ][0], null
      )
      public_ipv6_address = try(
        [
          for a in m.spec.addresses : lower(a)
          if can(cidrsubnet("${a}/128", 0, 0))
          && !can(regex(local.ipv6_non_public_pattern, lower(a)))
        ][0], null
      )
    }
  } : {}
}

data "external" "talos_member" {
  count = var.cluster_autoscaler_discovery_enabled ? 1 : 0

  program = [
    "sh", "-c", <<-EOT
      set -eu

      talosconfig=$(mktemp)
      cleanup() { rm -f "$talosconfig"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE
      jq -r '.talosconfig' > "$talosconfig"

      if ${local.cluster_initialized}; then
        if talos_member_json=$(talosctl --talosconfig "$talosconfig" get member -n '${terraform_data.talos_access_data.output.talos_primary_node}' -o json); then
          printf '%s' "$talos_member_json" | jq -c -s '{
            control_plane: (
              map(select(.spec.machineType == "controlplane")) | tostring
            ),
            worker: (
              map(select(
                .spec.machineType == "worker"
                and (.spec.hostname | test("${local.cluster_autoscaler_hostname_pattern}") | not)
              )) | tostring
            ),
            cluster_autoscaler: (
              map(select(
                .spec.machineType == "worker"
                and (.spec.hostname | test("${local.cluster_autoscaler_hostname_pattern}"))
              )) | tostring
            )
          }'
        else
          printf '%s\n' "talosctl failed" >&2
          exit 1
        fi
      else
        printf '%s\n' '{"control_plane":"[]","cluster_autoscaler":"[]","worker":"[]"}'
      fi
    EOT
  ]

  query = {
    talosconfig = data.talos_client_configuration.this.talos_config
  }

  depends_on = [
    data.external.client_prerequisites_check,
    data.external.talosctl_version_check,
    data.talos_machine_configuration.control_plane,
    data.talos_machine_configuration.worker,
    data.talos_machine_configuration.cluster_autoscaler
  ]
}
