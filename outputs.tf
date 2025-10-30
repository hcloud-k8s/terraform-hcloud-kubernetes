output "talosconfig" {
  description = "Raw Talos OS configuration file used for cluster access and management."
  value       = local.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig file for authenticating with the Kubernetes cluster."
  value       = local.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data, suitable for use with other Terraform providers or tools."
  value       = local.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Structured Talos configuration data, suitable for use with other Terraform providers or tools."
  value       = local.talosconfig_data
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Detailed configuration data for the Talos client."
  value       = data.talos_client_configuration.this
}

output "talos_machine_configurations_control_plane" {
  description = "Talos machine configurations for all control plane nodes."
  value       = data.talos_machine_configuration.control_plane
  sensitive   = true
}

output "talos_machine_configurations_worker" {
  description = "Talos machine configurations for all worker nodes."
  value       = data.talos_machine_configuration.worker
  sensitive   = true
}

output "control_plane_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_private_ipv4_list
}

output "control_plane_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_public_ipv4_list
}

output "control_plane_public_ipv6_list" {
  description = "List of public IPv6 addresses assigned to control plane nodes."
  value       = local.control_plane_public_ipv6_list
}

output "worker_private_ipv4_list" {
  description = "List of private IPv4 addresses assigned to worker nodes."
  value       = local.worker_private_ipv4_list
}

output "worker_public_ipv4_list" {
  description = "List of public IPv4 addresses assigned to worker nodes."
  value       = local.worker_public_ipv4_list
}

output "worker_public_ipv6_list" {
  description = "List of public IPv6 addresses assigned to worker nodes."
  value       = local.worker_public_ipv6_list
}

output "cilium_encryption_info" {
  description = "Cilium traffic encryption settings, including current state and IPsec details if enabled."
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

output "kube_api_load_balancer" {
  description = "Details about the Kubernetes API load balancer"
  value = var.kube_api_load_balancer_enabled ? {
    id           = hcloud_load_balancer.kube_api[0].id
    name         = local.kube_api_load_balancer_name
    public_ipv4  = local.kube_api_load_balancer_public_ipv4
    public_ipv6  = local.kube_api_load_balancer_public_ipv6
    private_ipv4 = local.kube_api_load_balancer_private_ipv4
  } : null
}
