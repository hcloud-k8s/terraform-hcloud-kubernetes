output "talosconfig" {
  description = "Configuration data for Talos OS"
  value       = local.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubeconfig data used for cluster authentication"
  value       = local.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data to supply to other providers"
  value       = local.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Structured talosconfig data to supply to other providers"
  value       = local.talosconfig_data
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Talos client configuration details"
  value       = data.talos_client_configuration.this
}

output "talos_machine_configurations_control_plane" {
  description = "Talos machine configurations for control plane nodes"
  value       = data.talos_machine_configuration.control_plane
  sensitive   = true
}

output "talos_machine_configurations_worker" {
  description = "Talos machine configurations for worker nodes"
  value       = data.talos_machine_configuration.worker
  sensitive   = true
}

output "control_plane_private_ipv4_list" {
  description = "Private IPv4 addresses of all control plane nodes"
  value       = local.control_plane_private_ipv4_list
}

output "control_plane_public_ipv4_list" {
  description = "Public IPv4 addresses of all control plane nodes"
  value       = local.control_plane_public_ipv4_list
}

output "control_plane_public_ipv6_list" {
  description = "Public IPv6 addresses of all control plane nodes"
  value       = local.control_plane_public_ipv6_list
}

output "worker_private_ipv4_list" {
  description = "Private IPv4 addresses of all worker nodes"
  value       = local.worker_private_ipv4_list
}

output "worker_public_ipv4_list" {
  description = "Public IPv4 addresses of all worker nodes"
  value       = local.worker_public_ipv4_list
}

output "worker_public_ipv6_list" {
  description = "Public IPv6 addresses of all worker nodes"
  value       = local.worker_public_ipv6_list
}

output "cilium_encryption_info" {
  description = "Information about Cilium traffic encryption"
  value = {
    encryption_enabled = var.cilium_encryption_enabled
    encryption_type    = var.cilium_encryption_type

    ipsec = local.cilium_ipsec_enabled ? {
      current_key_id = var.cilium_ipsec_key_id
      next_key_id    = local.cilium_ipsec_key_config["next_id"]
      algorithm      = var.cilium_ipsec_algorithm
      key_size_bits  = var.cilium_ipsec_key_size
      secret_name    = local.cilium_ipsec_keys_manifest.metadata["name"]
      namespace      = local.cilium_ipsec_keys_manifest.metadata["namespace"]
    } : {}
  }
}
