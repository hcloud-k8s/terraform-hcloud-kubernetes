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
    sha1(local.talosconfig),
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
    sha1(local.kubeconfig),
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

resource "terraform_data" "create_extended_worker_config" {


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

}

