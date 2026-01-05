# Dedicated Servers (Hetzner Robot)
# This file manages dedicated bare-metal servers joining the cluster as workers.
# Servers must be pre-provisioned with vSwitch connectivity to the cluster network.

locals {
  # Normalize dedicated servers with computed fields
  dedicated_servers_normalized = [
    for s in var.dedicated_servers : {
      hostname          = s.hostname
      vswitch_id        = s.vswitch_id
      private_ipv4      = s.private_ipv4
      network_interface = s.network_interface
      mode              = s.mode
      labels = merge(
        s.labels,
        { "node.kubernetes.io/dedicated-server" = "true" }
      )
      annotations = s.annotations
      taints = [for taint in s.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )]
      install_disk        = s.install_disk
      install_talos       = s.install_talos
      rescue_ssh_host     = s.rescue_ssh_host
      rescue_ssh_user     = s.rescue_ssh_user
      rescue_ssh_key_path = s.rescue_ssh_key_path
    }
  ]

  # Map for lookups
  dedicated_servers_map = {
    for s in local.dedicated_servers_normalized : s.hostname => s
  }

  # Filter by mode
  dedicated_servers_talos = [
    for s in local.dedicated_servers_normalized : s if s.mode == "talos"
  ]
  dedicated_servers_manual = [
    for s in local.dedicated_servers_normalized : s if s.mode == "manual"
  ]

  # IP lists for health checks
  dedicated_servers_private_ipv4_list = [
    for s in local.dedicated_servers_normalized : s.private_ipv4
  ]
  dedicated_servers_talos_private_ipv4_list = [
    for s in local.dedicated_servers_talos : s.private_ipv4
  ]

  # Group by vSwitch ID for subnet creation (keys must be strings)
  dedicated_servers_by_vswitch = {
    for s in local.dedicated_servers_normalized :
    tostring(s.vswitch_id) => s...
  }
}


# vSwitch Subnets
# Create one vSwitch-type subnet per unique vSwitch ID

resource "hcloud_network_subnet" "dedicated_vswitch" {
  for_each = local.dedicated_servers_by_vswitch

  network_id   = local.hcloud_network_id
  type         = "vswitch"
  network_zone = local.hcloud_network_zone
  vswitch_id   = tonumber(each.key)

  # Allocate from the end of the node CIDR range (before autoscaler subnet)
  ip_range = cidrsubnet(
    local.network_node_ipv4_cidr,
    local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1],
    pow(2, local.network_node_ipv4_subnet_mask_size - split("/", local.network_node_ipv4_cidr)[1]) - 2 - index(keys(local.dedicated_servers_by_vswitch), each.key)
  )

  depends_on = [
    hcloud_network_subnet.control_plane,
    hcloud_network_subnet.load_balancer,
    hcloud_network_subnet.worker
  ]
}


# Talos Configuration (mode: talos)

locals {
  # Talos config patches for dedicated servers
  dedicated_server_talos_config_patch = {
    for s in local.dedicated_servers_talos : s.hostname => {
      machine = {
        install = {
          disk            = s.install_disk
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        nodeLabels      = s.labels
        nodeAnnotations = s.annotations
        certSANs        = local.certificate_san
        network = {
          hostname = s.hostname
          interfaces = [{
            interface = s.network_interface
            addresses = ["${s.private_ipv4}/${local.network_node_ipv4_subnet_mask_size}"]
            routes = concat(
              [{
                network = local.network_ipv4_cidr
                gateway = local.network_ipv4_gateway
              }],
              local.talos_extra_routes
            )
          }]
          nameservers      = local.talos_nameservers
          extraHostEntries = local.talos_extra_host_entries
        }
        kubelet = {
          extraArgs = merge(
            {
              "cloud-provider"             = "external"
              "rotate-server-certificates" = true
            },
            var.kubernetes_kubelet_extra_args
          )
          extraConfig = merge(
            {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
              registerWithTaints              = s.taints
              systemReserved = {
                cpu               = "100m"
                memory            = "300Mi"
                ephemeral-storage = "1Gi"
              }
              kubeReserved = {
                cpu               = "100m"
                memory            = "350Mi"
                ephemeral-storage = "1Gi"
              }
            },
            var.kubernetes_kubelet_extra_config
          )
          extraMounts = local.talos_kubelet_extra_mounts
          nodeIP = {
            validSubnets = [local.network_node_ipv4_cidr]
          }
        }
        kernel = {
          modules = var.talos_kernel_modules
        }
        sysctls = merge(
          {
            "net.core.somaxconn"                 = "65535"
            "net.core.netdev_max_backlog"        = "4096"
            "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}"
            "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
          },
          var.talos_sysctls_extra_args
        )
        registries           = var.talos_registries
        systemDiskEncryption = local.talos_system_disk_encryption
        features = {
          hostDNS = local.talos_host_dns
        }
        time = {
          servers = var.talos_time_servers
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.network_pod_ipv4_cidr]
          serviceSubnets = [local.network_service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = {
          disabled = var.cilium_kube_proxy_replacement_enabled
        }
        discovery = local.talos_discovery
      }
    }
  }
}

# Generate Talos machine configurations
data "talos_machine_configuration" "dedicated_server" {
  for_each = { for s in local.dedicated_servers_talos : s.hostname => s }

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [yamlencode(local.dedicated_server_talos_config_patch[each.key])],
    [for patch in var.dedicated_servers_config_patches : yamlencode(patch)]
  )
}

# Apply Talos configuration to dedicated servers
# Note: This requires the server to be running Talos and reachable
resource "talos_machine_configuration_apply" "dedicated_server" {
  for_each = { for s in local.dedicated_servers_talos : s.hostname => s }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.dedicated_server[each.key].machine_configuration
  endpoint                    = each.value.private_ipv4
  node                        = each.value.private_ipv4
  apply_mode                  = var.talos_machine_configuration_apply_mode

  on_destroy = {
    graceful = var.cluster_graceful_destroy
    reset    = false # Don't reset dedicated servers on destroy
    reboot   = false
  }

  depends_on = [
    hcloud_network_subnet.dedicated_vswitch,
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.worker
  ]
}


# Automated Talos Installation (optional)
# Installs Talos on dedicated servers via SSH when in rescue mode

resource "terraform_data" "dedicated_server_talos_install" {
  for_each = {
    for s in local.dedicated_servers_talos : s.hostname => s
    if s.install_talos
  }

  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id,
    each.value.install_disk
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -eu

      echo "Installing Talos on dedicated server ${each.value.hostname} (${each.value.rescue_ssh_host})..."

      # SSH into rescue mode and install Talos
      ssh -i "${each.value.rescue_ssh_key_path}" \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=30 \
          ${each.value.rescue_ssh_user}@${each.value.rescue_ssh_host} \
          "set -eu; \
           echo 'Downloading Talos image...'; \
           wget -q -O /tmp/talos.raw.xz '${local.talos_amd64_image_url}'; \
           echo 'Writing Talos to disk ${each.value.install_disk}...'; \
           xz -d -c /tmp/talos.raw.xz | dd of=${each.value.install_disk} bs=4M status=progress; \
           sync; \
           echo 'Talos installation complete. Rebooting...'; \
           reboot" || true

      echo "Server ${each.value.hostname} is rebooting into Talos."
      echo "Waiting 60 seconds for Talos to boot..."
      sleep 60

      echo "Talos installation completed for ${each.value.hostname}."
      echo "The machine configuration will be applied automatically."
    EOT
  }

  depends_on = [
    hcloud_network_subnet.dedicated_vswitch
  ]
}


# Bootstrap Tokens (mode: manual)
# Generate Kubernetes bootstrap tokens for manual mode servers

resource "random_id" "dedicated_server_bootstrap_token_id" {
  for_each = { for s in local.dedicated_servers_manual : s.hostname => s }

  byte_length = 3
}

resource "random_password" "dedicated_server_bootstrap_token_secret" {
  for_each = { for s in local.dedicated_servers_manual : s.hostname => s }

  length  = 16
  special = false
  lower   = true
  upper   = false
}

locals {
  # Build join information for manual mode servers
  dedicated_servers_join_info = {
    for s in local.dedicated_servers_manual : s.hostname => {
      hostname     = s.hostname
      private_ipv4 = s.private_ipv4
      token_id     = random_id.dedicated_server_bootstrap_token_id[s.hostname].hex
      token_secret = random_password.dedicated_server_bootstrap_token_secret[s.hostname].result
      token        = "${random_id.dedicated_server_bootstrap_token_id[s.hostname].hex}.${random_password.dedicated_server_bootstrap_token_secret[s.hostname].result}"
      api_server   = local.kube_api_url_internal
      labels       = s.labels
      taints       = s.taints
      # Generate bootstrap token secret manifest
      bootstrap_secret_manifest = yamlencode({
        apiVersion = "v1"
        kind       = "Secret"
        metadata = {
          name      = "bootstrap-token-${random_id.dedicated_server_bootstrap_token_id[s.hostname].hex}"
          namespace = "kube-system"
        }
        type = "bootstrap.kubernetes.io/token"
        stringData = {
          "token-id"                       = random_id.dedicated_server_bootstrap_token_id[s.hostname].hex
          "token-secret"                   = random_password.dedicated_server_bootstrap_token_secret[s.hostname].result
          "usage-bootstrap-authentication" = "true"
          "usage-bootstrap-signing"        = "true"
          "auth-extra-groups"              = "system:bootstrappers:dedicated-workers"
          "description"                    = "Bootstrap token for dedicated server ${s.hostname}"
        }
      })
    }
  }
}
