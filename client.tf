locals {
  kubeconfig = replace(
    talos_cluster_kubeconfig.this.kubeconfig_raw,
    "/(\\s+server:).*/",
    "$1 ${local.kube_api_url_external}"
  )
  talosconfig = data.talos_client_configuration.this.talos_config

  kubeconfig_data = {
    name   = var.cluster_name
    server = local.kube_api_url_external
    ca     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    cert   = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    key    = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }

  talosconfig_data = {
    name      = data.talos_client_configuration.this.cluster_name
    endpoints = data.talos_client_configuration.this.endpoints
    ca        = base64decode(data.talos_client_configuration.this.client_configuration.ca_certificate)
    cert      = base64decode(data.talos_client_configuration.this.client_configuration.client_certificate)
    key       = base64decode(data.talos_client_configuration.this.client_configuration.client_key)
  }
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.talos_endpoints
  nodes                = [local.talos_primary_node_private_ipv4]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.talos_primary_endpoint

  depends_on = [talos_machine_configuration_apply.control_plane]
}

resource "terraform_data" "create_talosconfig" {
  count = var.cluster_talosconfig_path != null ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(local.talosconfig)),
    var.cluster_talosconfig_path
  ]

  input = {
    cluster_talosconfig_path = var.cluster_talosconfig_path
  }

  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      printf '%s' "$TALOSCONFIG_CONTENT" > "$CLUSTER_TALOSCONFIG_PATH"
    EOT
    environment = {
      TALOSCONFIG_CONTENT      = local.talosconfig
      CLUSTER_TALOSCONFIG_PATH = var.cluster_talosconfig_path
    }
  }

  provisioner "local-exec" {
    when       = destroy
    quiet      = true
    on_failure = continue
    command    = <<-EOT
      set -eu

      if [ -f "$CLUSTER_TALOSCONFIG_PATH" ]; then
        cp -f "$CLUSTER_TALOSCONFIG_PATH" "$CLUSTER_TALOSCONFIG_PATH.bak"
      fi
    EOT
    environment = {
      CLUSTER_TALOSCONFIG_PATH = self.input.cluster_talosconfig_path
    }
  }

  depends_on = [talos_machine_configuration_apply.control_plane]
}

resource "terraform_data" "create_kubeconfig" {
  count = var.cluster_kubeconfig_path != null ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(local.kubeconfig)),
    var.cluster_kubeconfig_path
  ]

  input = {
    cluster_kubeconfig_path = var.cluster_kubeconfig_path
  }

  provisioner "local-exec" {
    when    = create
    quiet   = true
    command = <<-EOT
      set -eu

      printf '%s' "$KUBECONFIG_CONTENT" > "$CLUSTER_KUBECONFIG_PATH"
    EOT
    environment = {
      KUBECONFIG_CONTENT      = local.kubeconfig
      CLUSTER_KUBECONFIG_PATH = var.cluster_kubeconfig_path
    }
  }

  provisioner "local-exec" {
    when       = destroy
    quiet      = true
    on_failure = continue
    command    = <<-EOT
      set -eu

      if [ -f "$CLUSTER_KUBECONFIG_PATH" ]; then
        cp -f "$CLUSTER_KUBECONFIG_PATH" "$CLUSTER_KUBECONFIG_PATH.bak"
      fi
    EOT
    environment = {
      CLUSTER_KUBECONFIG_PATH = self.input.cluster_kubeconfig_path
    }
  }

  depends_on = [talos_machine_configuration_apply.control_plane]
}

data "external" "client_prerequisites_check" {
  count = var.client_prerequisites_check_enabled ? 1 : 0

  program = [
    "sh", "-c", <<-EOT
      set -eu

      missing=0

      if ! command -v packer >/dev/null 2>&1; then
          printf '\n%s' ' - packer is not installed or not in PATH. Install it at https://developer.hashicorp.com/packer/install' >&2
          missing=1
      fi

      if ! command -v jq >/dev/null 2>&1; then
          printf '\n%s' ' - jq is not installed or not in PATH. Install it at https://jqlang.org/download/' >&2
          missing=1
      fi

      if ! command -v talosctl >/dev/null 2>&1; then
          printf '\n%s' ' - talosctl is not installed or not in PATH. Install it at https://www.talos.dev/latest/talos-guides/install/talosctl' >&2
          missing=1
      fi

      printf '%s' '{}'
      exit "$missing"
    EOT
  ]
}

data "external" "talosctl_version_check" {
  count = var.talosctl_version_check_enabled ? 1 : 0

  program = [
    "sh", "-c", <<-EOT
      set -eu

      parse() {
        case $1 in
          *[vV][0-9]*.[0-9]*.[0-9]*)
            v=$${1##*[vV]}
            maj=$${v%%.*}
            r=$${v#*.}
            min=$${r%%.*}
            patch=$${r#*.}
            patch=$${patch%%[!0-9]*}
            printf '%s %s %s\n' "$maj" "$min" "$patch"
            return 0
            ;;
        esac
        return 1
      }

      parsed_version=$(
        talosctl version --client --short |
        while IFS= read -r line; do
          if out=$(parse "$line"); then
            printf '%s\n' "$out"
            break
          fi
        done
      )

      if [ -z "$parsed_version" ]; then
        printf '%s\n' "Could not parse talosctl client version" >&2
        exit 1
      fi

      set -- $parsed_version; major=$1; minor=$2; patch=$3
      if [ "$major" -lt "${local.talos_version_major}" ] ||
       { [ "$major" -eq "${local.talos_version_major}" ] && [ "$minor" -lt "${local.talos_version_minor}" ]; } ||
       { [ "$major" -eq "${local.talos_version_major}" ] && [ "$minor" -eq "${local.talos_version_minor}" ] && [ "$patch" -lt "${local.talos_version_patch}" ]; }
      then
        printf '%s\n' "talosctl version ($major.$minor.$patch) is lower than Talos target version: ${local.talos_version_major}.${local.talos_version_minor}.${local.talos_version_patch}" >&2
        exit 1
      fi

      printf '%s' "{\"talosctl_version\": \"$major.$minor.$patch\"}"
    EOT
  ]

  depends_on = [data.external.client_prerequisites_check]
}
