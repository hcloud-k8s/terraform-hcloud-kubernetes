# Cluster Configuration
variable "cluster_name" {
  type        = string
  description = "Specifies the name of the cluster. This name is used to identify the cluster within the infrastructure and should be unique across all deployments."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,14}[a-z0-9])?$", var.cluster_name))
    error_message = "The cluster name must start and end with a lowercase letter or number, can contain hyphens, and must be no longer than 16 characters."
  }
}

variable "cluster_domain" {
  type        = string
  default     = "cluster.local"
  description = "Specifies the domain name used by the cluster. This domain name is integral for internal networking and service discovery within the cluster. The default is 'cluster.local', which is commonly used for local Kubernetes clusters."

  validation {
    condition     = can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)$", var.cluster_domain))
    error_message = "The cluster domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "cluster_access" {
  type        = string
  default     = "public"
  description = "Defines how the cluster is accessed externally. Specifies if access should be through public or private IPs."

  validation {
    condition     = contains(["public", "private"], var.cluster_access)
    error_message = "Invalid value for 'cluster_access'. Valid options are 'public' or 'private'."
  }
}

variable "cluster_kubeconfig_path" {
  type        = string
  default     = null
  description = "If not null, the kubeconfig will be written to a file speficified."
}

variable "cluster_talosconfig_path" {
  type        = string
  default     = null
  description = "If not null, the talosconfig will be written to a file speficified."
}

variable "cluster_graceful_destroy" {
  type        = bool
  default     = true
  description = "Determines whether a graceful destruction process is enabled for Talos nodes. When enabled, it ensures that nodes are properly drained and decommissioned before being destroyed, minimizing disruption in the cluster."
}

variable "cluster_healthcheck_enabled" {
  type        = bool
  default     = true
  description = "Determines whether are executed during cluster deployment and upgrade."
}

variable "cluster_delete_protection" {
  type        = bool
  default     = true
  description = "Adds delete protection for resources that support it."
}


# Network Configuration
variable "network_ipv4_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Specifies the main IPv4 CIDR block for the network. This CIDR block is used to allocate IP addresses within the network."
}

variable "network_node_ipv4_cidr" {
  type        = string
  default     = null # 10.0.64.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Node CIDR used for allocating IP addresses to both Control Plane and Worker nodes within the cluster. If not explicitly provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_node_ipv4_subnet_mask_size" {
  type        = number
  default     = null # /25 when network_pod_ipv4_cidr is 10.0.128.0/17
  description = "Specifies the subnet mask size used for node pools within the cluster. This setting determines the network segmentation precision, with a smaller mask size allowing more IP addresses per subnet. If not explicitly provided, an optimal default size is dynamically calculated from the network_pod_ipv4_cidr."
}

variable "network_service_ipv4_cidr" {
  type        = string
  default     = null # 10.0.96.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Service CIDR block used for allocating ClusterIPs to services within the cluster. If not provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_pod_ipv4_cidr" {
  type        = string
  default     = null # 10.0.128.0/17 when network_ipv4_cidr is 10.0.0.0/16
  description = "Defines the Pod CIDR block allocated for use by pods within the cluster. This CIDR block is essential for internal pod communications. If a specific subnet is not provided, a default is dynamically calculated from the network_ipv4_cidr."
}

variable "network_native_routing_cidr" {
  type        = string
  default     = null
  description = "Specifies the CIDR block that the CNI assumes will be routed natively by the underlying network infrastructure without the need for SNAT."
}


# Firewall Configuration
variable "firewall_use_current_ipv4" {
  type        = bool
  default     = null
  description = "Determines whether the current IPv4 address is used for Talos and Kube API firewall rules. If `cluster_access` is set to `public`, the default is true."
}

variable "firewall_use_current_ipv6" {
  type        = bool
  default     = null
  description = "Determines whether the current IPv6 /64 CIDR is used for Talos and Kube API firewall rules. If `cluster_access` is set to `public`, the default is true."
}

variable "firewall_extra_rules" {
  type = list(object({
    description     = string
    direction       = string
    source_ips      = optional(string)
    destination_ips = optional(string)
    protocol        = string
    port            = optional(number)
  }))
  default     = []
  description = "Additional firewall rules to apply to the cluster."

  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        rule.direction == "in" || rule.direction == "out"
      )
    ])
    error_message = "Each rule must specify 'direction' as 'in' or 'out'."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        rule.protocol == "tcp" || rule.protocol == "udp" || rule.protocol == "icmp" ||
        rule.protocol == "gre" || rule.protocol == "esp"
      )
    ])
    error_message = "Each rule must specify 'protocol' as 'tcp', 'udp', 'icmp', 'gre', or 'esp'."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        (rule.direction == "in" && rule.source_ips != null && rule.destination_ips == null) ||
        (rule.direction == "out" && rule.destination_ips != null && rule.source_ips == null)
      )
    ])
    error_message = "For 'in' direction, 'source_ips' must be provided and 'destination_ips' must be null. For 'out' direction, 'destination_ips' must be provided and 'source_ips' must be null."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        (rule.protocol != "icmp" && rule.protocol != "gre" && rule.protocol != "esp") || (rule.port == null)
      )
    ])
    error_message = "Port must not be specified when 'protocol' is 'icmp', 'gre', or 'esp'."
  }
}

variable "firewall_kube_api_source" {
  type        = list(string)
  default     = null
  description = "Source networks that have access to Kube API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
}

variable "firewall_talos_api_source" {
  type        = list(string)
  default     = null
  description = "Source networks that have access to Talos API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
}


# Control Plane
variable "control_plane_public_vip_ipv4_enabled" {
  type        = bool
  default     = false
  description = "If true, a floating IP will be created and assigned to the Control Plane nodes."
}

variable "control_plane_public_vip_ipv4_id" {
  type        = number
  default     = null
  description = "Specifies the Floating IP ID for the Control Plane nodes. A new floating IP will be created if this is set to null."
}

variable "control_plane_private_vip_ipv4_enabled" {
  type        = bool
  default     = true
  description = "If true, an alias IP will be created and assigned to the Control Plane nodes."
}

variable "control_plane_nodepools" {
  type = list(object({
    name        = string
    location    = string
    type        = string
    backups     = optional(bool, false)
    keep_disk   = optional(bool, false)
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
    taints      = optional(list(string), [])
    count       = optional(number, 1)
  }))
  description = "Configures the number and attributes of Control Plane nodes."

  validation {
    condition     = length(var.control_plane_nodepools) == length(distinct([for np in var.control_plane_nodepools : np.name]))
    error_message = "Control Plane nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) <= 9
    error_message = "The total count of all nodes in Control Plane nodepools must not exceed 9."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) % 2 == 1
    error_message = "The sum of all Control Plane nodes must be odd to ensure high availability."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : contains([
        "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
      ], np.location)
    ])
    error_message = "Each nodepool location must be one of: 'fsn1' (Falkenstein), 'nbg1' (Nuremberg), 'hel1' (Helsinki), 'ash' (Ashburn), 'hil' (Hillsboro), 'sin' (Singapore)."
  }
}


# Worker
variable "worker_nodepools" {
  type = list(object({
    name            = string
    location        = string
    type            = string
    backups         = optional(bool, false)
    keep_disk       = optional(bool, false)
    labels          = optional(map(string), {})
    annotations     = optional(map(string), {})
    taints          = optional(list(string), [])
    count           = optional(number, 1)
    placement_group = optional(bool, true)
  }))
  default     = []
  description = "Defines configuration settings for Worker node pools within the cluster."

  validation {
    condition     = length(var.worker_nodepools) == length(distinct([for np in var.worker_nodepools : np.name]))
    error_message = "Worker nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition = sum(concat(
      [for worker_nodepool in var.worker_nodepools : coalesce(worker_nodepool.count, 1)],
      [for control_nodepool in var.control_plane_nodepools : coalesce(control_nodepool.count, 1)]
    )) <= 100
    error_message = "The total count of nodes in both worker and Control Plane nodepools must not exceed 100 to ensure manageable cluster size."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : contains([
        "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
      ], np.location)
    ])
    error_message = "Each nodepool location must be one of: 'fsn1' (Falkenstein), 'nbg1' (Nuremberg), 'hel1' (Helsinki), 'ash' (Ashburn), 'hil' (Hillsboro), 'sin' (Singapore)."
  }
}


# Cluster Autoscaler
variable "cluster_autoscaler_helm_repository" {
  type        = string
  default     = "https://kubernetes.github.io/autoscaler"
  description = "URL of the Helm repository where the Cluster Autoscaler chart is located."
}

variable "cluster_autoscaler_helm_chart" {
  type        = string
  default     = "cluster-autoscaler"
  description = "Name of the Helm chart used for deploying Cluster Autoscaler."
}

variable "cluster_autoscaler_helm_version" {
  type        = string
  default     = "v9.43.2"
  description = "Version of the Cluster Autoscaler Helm chart to deploy."
}

variable "cluster_autoscaler_helm_values" {
  type        = map(any)
  default     = {}
  description = "Custom Helm values for the Cluster Autoscaler chart deployment. These values will merge with and will override the default values provided by the Cluster Autoscaler Helm chart."
}

variable "cluster_autoscaler_enforce_node_group_min_size" {
  type        = bool
  default     = false
  description = "Specifies whether the Cluster Autoscaler should scale up node groups to the configured minimum size."
}

variable "cluster_autoscaler_nodepools" {
  type = list(object({
    name        = string
    location    = string
    type        = string
    labels      = optional(map(string), {})
    annotations = optional(map(string), {})
    taints      = optional(list(string), [])
    min         = optional(number, 0)
    max         = number
  }))
  default     = []
  description = "Defines configuration settings for Autoscaler node pools within the cluster."

  validation {
    condition     = length(var.cluster_autoscaler_nodepools) == length(distinct([for np in var.cluster_autoscaler_nodepools : np.name]))
    error_message = "Autoscaler nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition = alltrue([
      for np in var.cluster_autoscaler_nodepools : np.max >= coalesce(np.min, 0)
    ])
    error_message = "Max size of a nodepool must be greater than or equal to its Min size."
  }

  validation {
    condition = sum(concat(
      [for control_nodepool in var.control_plane_nodepools : coalesce(control_nodepool.count, 1)],
      [for worker_nodepool in var.worker_nodepools : coalesce(worker_nodepool.count, 1)],
      [for cluster_autoscaler_nodepools in var.cluster_autoscaler_nodepools : cluster_autoscaler_nodepools.max]
    )) <= 100
    error_message = "The total count of nodes must not exceed 100."
  }

  validation {
    condition = alltrue([
      for np in var.cluster_autoscaler_nodepools : contains([
        "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
      ], np.location)
    ])
    error_message = "Each nodepool location must be one of: 'fsn1' (Falkenstein), 'nbg1' (Nuremberg), 'hel1' (Helsinki), 'ash' (Ashburn), 'hil' (Hillsboro), 'sin' (Singapore)."
  }
}


# Talos
variable "talos_version" {
  type        = string
  default     = "v1.7.7"
  description = "Specifies the version of Talos to be used in generated machine configurations."
}

variable "talos_schematic_id" {
  type        = string
  default     = null
  description = "Specifies the Talos schematic ID used for selecting the specific Image and Installer versions in deployments. This has precedence over `talos_image_extensions`"
}

variable "talos_image_extensions" {
  type        = list(string)
  default     = []
  description = "Specifies Talos image extensions for additional functionality on top of the default Talos Linux capabilities. See: https://github.com/siderolabs/extensions"
}

variable "talos_kubelet_extra_mounts" {
  type = list(object({
    source      = string
    destination = optional(string)
    type        = optional(string, "bind")
    options     = optional(list(string), ["bind", "rshared", "rw"])
  }))
  default     = []
  description = "Defines extra kubelet mounts for Talos with configurable 'source', 'destination' (defaults to 'source' if unset), 'type' (defaults to 'bind'), and 'options' (defaults to ['bind', 'rshared', 'rw'])"

  validation {
    condition = (
      length(var.talos_kubelet_extra_mounts) ==
      length(toset([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)])) &&
      (!var.longhorn_enabled || !contains([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)], "/var/lib/longhorn"))
    )
    error_message = "Each destination in talos_kubelet_extra_mounts must be unique and cannot include the Longhorn default data path if Longhorn is enabled."
  }
}

variable "talos_extra_kernel_args" {
  type        = list(string)
  default     = []
  description = "Defines a list of extra kernel commandline parameters."
}

variable "talos_kernel_modules" {
  type = list(object({
    name       = string
    parameters = optional(list(string))
  }))
  default     = null
  description = "Defines a list of kernel modules to be loaded during system boot, along with optional parameters for each module. This allows for customized kernel behavior in the Talos environment."
}

variable "talos_machine_configuration_apply_mode" {
  type        = string
  default     = "auto"
  description = "Determines how changes to Talos machine configurations are applied. 'auto' (default) applies changes immediately and reboots if necessary. 'reboot' applies changes and then reboots the node. 'no_reboot' applies changes immediately without a reboot, failing if a reboot is required. 'staged' stages changes to apply on the next reboot without initiating a reboot."

  validation {
    condition     = contains(["auto", "reboot", "no_reboot", "staged"], var.talos_machine_configuration_apply_mode)
    error_message = "The talos_machine_configuration_apply_mode must be 'auto', 'reboot', 'no_reboot', or 'staged'."
  }
}

variable "talos_sysctls_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies a map of sysctl key-value pairs for configuring additional kernel parameters. These settings allow for detailed customization of the operating system's behavior at runtime."
}

variable "talos_state_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the state (`/system/state`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ephemeral_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the ephemeral (`/var`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Determines whether IPv6 is enabled for the Talos operating system. Enabling this setting configures the Talos OS to support IPv6 networking capabilities."
}

variable "talos_public_ipv4_enabled" {
  type        = bool
  default     = true
  description = "Determines whether public IPv4 addresses are enabled for nodes the cluster. If true, each node is assigned a public IPv4 address."
}

variable "talos_public_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Determines whether public IPv6 addresses are enabled for nodes in the cluster. If true, each node is assigned a public IPv4 address."
}

variable "talos_extra_routes" {
  type        = list(string)
  default     = []
  description = "Specifies CIDR blocks to be added as extra routes for the internal network interface, using the Hetzner router (first usable IP in the network) as the gateway."

  validation {
    condition     = alltrue([for cidr in var.talos_extra_routes : can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))])
    error_message = "All entries in extra_routes must be valid CIDR notations."
  }
}

variable "talos_coredns_enabled" {
  type        = bool
  default     = true
  description = "Determines whether CoreDNS is enabled in the Talos cluster. When enabled, CoreDNS serves as the primary DNS service provider in Kubernetes."
}

variable "talos_nameservers" {
  type = list(string)
  default = [
    "185.12.64.1", "185.12.64.2",
    "2a01:4ff:ff00::add:1", "2a01:4ff:ff00::add:2"
  ]
  description = "Specifies a list of IPv4 and IPv6 nameserver addresses used for DNS resolution by nodes and CoreDNS within the cluster."
}

variable "talos_extra_host_entries" {
  type = list(object({
    ip      = string
    aliases = list(string)
  }))
  default     = []
  description = "Specifies additional host entries to be added on each node. Each entry must include an IP address and a list of aliases associated with that IP."
}

variable "talos_time_servers" {
  type        = list(string)
  default     = ["ntp1.hetzner.de", "ntp2.hetzner.com", "ntp3.hetzner.net"]
  description = "Specifies a list of time server addresses used for network time synchronization across the cluster. These servers ensure that all cluster nodes maintain accurate and synchronized time."
}

variable "talos_registries" {
  type = object({
    mirrors = map(object({
      endpoints    = list(string)
      overridePath = optional(bool)
    }))
  })
  default     = null
  description = <<-EOF
    Specifies a list of registry mirrors to be used for container image retrieval. This configuration helps in specifying alternate sources or local mirrors for image registries, enhancing reliability and speed of image downloads.
    Example configuration:
    ```
    registries = {
      mirrors = {
        "docker.io" = {
          endpoints = [
            "http://localhost:5000",
            "https://docker.io"
          ]
        }
      }
    }
    ```
  EOF
}


# Talos Backup
variable "talos_backup_version" {
  type        = string
  default     = "v0.1.0-beta.2-1-g9ccc125"
  description = "Specifies the version of Talos Backup to be used in generated machine configurations."
}

variable "talos_backup_s3_hcloud_url" {
  type        = string
  default     = null
  description = "Hetzner Cloud S3 endpoint for Talos Backup."
}

variable "talos_backup_s3_region" {
  type        = string
  default     = null
  description = "S3 region for Talos Backup."
}

variable "talos_backup_s3_endpoint" {
  type        = string
  default     = null
  description = "S3 endpoint for Talos Backup."
}

variable "talos_backup_s3_bucket" {
  type        = string
  default     = null
  description = "S3 bucket name for Talos Backup."
}

variable "talos_backup_s3_prefix" {
  type        = string
  default     = null
  description = "S3 prefix for Talos Backup."
}

variable "talos_backup_s3_path_style" {
  type        = bool
  default     = false
  description = "Use path style S3 for Talos Backup. Set this to false if you have another s3 like endpoint such as minio."
}

variable "talos_backup_s3_access_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "S3 Access Key for Talos Backup."
}

variable "talos_backup_s3_secret_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "S3 Secret Access Key for Talos Backup."
}

variable "talos_backup_age_x25519_public_key" {
  type        = string
  default     = null
  description = "AGE X25519 Public Key for client side Talos Backup encryption."
}

variable "talos_backup_schedule" {
  type        = string
  default     = "0 * * * *"
  description = "The schedule for Talos Backup"
}


# Kubernetes
variable "kubernetes_version" {
  type        = string
  default     = "v1.30.5"
  description = "Specifies the Kubernetes version to deploy."
}

variable "kubernetes_automatic_upgrade" {
  type        = bool
  default     = true
  description = "Determines whether Kubernetes is automatically upgraded during a terraform apply."
}

variable "kubernetes_kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to pass to the kubelet service. These arguments can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}


# Kubernetes API
variable "kube_api_hostname" {
  type        = string
  default     = null
  description = "Specifies the hostname for external access to the Kubernetes API server. This must be a valid domain name, set to the API's public IP address."
}

variable "kube_api_load_balancer_enabled" {
  type        = bool
  default     = false
  description = "Determines whether a load balancer is enabled for the Kubernetes API server. Enabling this setting provides high availability and distributed traffic management to the API server."
}

variable "kube_api_load_balancer_public_network_enabled" {
  type        = bool
  default     = null
  description = "Enables the public interface for the Kubernetes API load balancer. When enabled, the API is accessible publicly without a firewall."
}

variable "kube_api_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to be passed to the kube-apiserver. This allows for customization of the API server's behavior according to specific cluster requirements."
}


# Talos CCM
variable "talos_ccm_version" {
  type        = string
  default     = "v1.8.1"
  description = "Specifies the version of the Talos Cloud Controller Manager (CCM) to use. This version controls cloud-specific integration features in the Talos operating system."
}

# Hetzner Cloud
variable "hcloud_ccm_version" {
  type        = string
  default     = "v1.20.0"
  description = "Specifies the version of the Hetzner Cloud Controller Manager (CCM) to deploy. This controls the integration features specific to Hetzner Cloud, facilitating the management of cloud resources."
}

variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token used for authentication with Hetzner Cloud services. This token should be treated as sensitive information."
  sensitive   = true
}

variable "hcloud_network_id" {
  type        = string
  default     = null
  description = "The Hetzner network ID of an existing network."
}

variable "hcloud_load_balancer_location" {
  type        = string
  default     = null
  description = "The default location for Hetzner load balancers."

  validation {
    condition = can(contains([
      "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
    ], var.hcloud_load_balancer_location)) || var.hcloud_load_balancer_location == null
    error_message = "Location must be one of: 'fsn1' (Falkenstein), 'nbg1' (Nuremberg), 'hel1' (Helsinki), 'ash' (Ashburn), 'hil' (Hillsboro), 'sin' (Singapore)."
  }
}

variable "hcloud_csi_version" {
  type        = string
  default     = "v2.9.0"
  description = "Specifies the version of the Hetzner Container Storage Interface (CSI) to deploy, enabling dynamic volume provisioning and management on Hetzner Cloud."
}

variable "hcloud_csi_enabled" {
  type        = bool
  default     = true
  description = "Enables the Hetzner Container Storage Interface (CSI)."
}


# Longhorn
variable "longhorn_helm_repository" {
  type        = string
  default     = "https://charts.longhorn.io"
  description = "URL of the Helm repository where the Longhorn chart is located."
}

variable "longhorn_helm_chart" {
  type        = string
  default     = "longhorn"
  description = "Name of the Helm chart used for deploying Longhorn."
}

variable "longhorn_helm_version" {
  type        = string
  default     = "v1.7.2"
  description = "Version of the Longhorn Helm chart to deploy."
}

variable "longhorn_helm_values" {
  type        = map(any)
  default     = {}
  description = "Custom Helm values for the Longhorn chart deployment. These values will merge with and will override the default values provided by the Longhorn Helm chart."
}

variable "longhorn_enabled" {
  type        = bool
  default     = false
  description = "Enable or disable Longhorn integration"
}


# Cilium
variable "cilium_version" {
  type        = string
  default     = "v1.16.3"
  description = "Specifies the version of Cilium to deploy in the Kubernetes cluster."
}

variable "cilium_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables transparent network encryption using Cilium within the Kubernetes cluster. When enabled, this feature provides added security for network traffic."
}

variable "cilium_egress_gateway_enabled" {
  type        = bool
  default     = false
  description = "Enables egress gateway to redirect and SNAT the traffic that leaves the cluster."
}

variable "cilium_service_monitor_enabled" {
  type        = bool
  default     = false
  description = "Enables service monitors for Prometheus if set to true."
}

variable "cilium_hubble_enabled" {
  type        = bool
  default     = false
  description = "Enables Hubble observability within Cilium, which may impact performance with an overhead of 1-15% depending on network traffic patterns and settings."
}

variable "cilium_hubble_relay_enabled" {
  type        = bool
  default     = false
  description = "Enables Hubble Relay, which requires Hubble to be enabled."

  validation {
    condition     = var.cilium_hubble_relay_enabled ? var.cilium_hubble_enabled : true
    error_message = "Hubble Relay cannot be enabled unless Hubble is also enabled."
  }
}

variable "cilium_hubble_ui_enabled" {
  type        = bool
  default     = false
  description = "Enables the Hubble UI, which requires Hubble Relay to be enabled."

  validation {
    condition     = var.cilium_hubble_ui_enabled ? var.cilium_hubble_relay_enabled : true
    error_message = "Hubble UI cannot be enabled unless Hubble Relay is also enabled."
  }
}


# Metrics Server
variable "metrics_server_helm_repository" {
  type        = string
  default     = "https://kubernetes-sigs.github.io/metrics-server"
  description = "URL of the Helm repository where the Longhorn chart is located."
}

variable "metrics_server_helm_chart" {
  type        = string
  default     = "metrics-server"
  description = "Name of the Helm chart used for deploying Metrics Server."
}

variable "metrics_server_helm_version" {
  type        = string
  default     = "3.12.2"
  description = "Version of the Metrics Server Helm chart to deploy."
}

variable "metrics_server_helm_values" {
  type        = map(any)
  default     = {}
  description = "Custom Helm values for the Metrics Server chart deployment. These values will merge with and will override the default values provided by the Metrics Server Helm chart."
}

variable "metrics_server_enabled" {
  type        = bool
  default     = true
  description = "Enables the the Kubernetes Metrics Server."
}


# Cert Manager
variable "cert_manager_version" {
  type        = string
  default     = "v1.15.2"
  description = "Specifies the version of cert-manager to deploy."
}

variable "cert_manager_enabled" {
  type        = bool
  default     = false
  description = "Enables the deployment of cert-manager for managing TLS certificates."
}


# Ingress
variable "ingress_nginx_version" {
  type        = string
  default     = "v4.11.1"
  description = "Specifies the Helm chart version of the Ingress-NGINX Controller to deploy."
}

variable "ingress_nginx_enabled" {
  type        = bool
  default     = false
  description = "Enables the deployment of the NGINX Ingress controller. Requires cert_manager_enabled to be true."

  validation {
    condition     = var.ingress_nginx_enabled ? var.cert_manager_enabled : true
    error_message = "Ingress NGINX can only be enabled if cert-manager is also enabled."
  }
}

variable "ingress_nginx_kind" {
  type        = string
  default     = "Deployment"
  description = "Specifies the type of Kubernetes controller to use for ingress-nginx. Valid options are 'Deployment' or 'DaemonSet'."

  validation {
    condition     = contains(["Deployment", "DaemonSet"], var.ingress_nginx_kind)
    error_message = "The ingress_nginx_kind must be either 'Deployment' or 'DaemonSet'."
  }
}

variable "ingress_nginx_replicas" {
  type        = number
  default     = null
  description = "Specifies the number of replicas for the NGINX Ingress controller. If not set, the default is 2 replicas for clusters with fewer than 3 Worker nodes, and 3 replicas for clusters with 3 or more Worker nodes."

  validation {
    condition     = var.ingress_nginx_kind != "DaemonSet" || var.ingress_nginx_replicas == null
    error_message = "ingress_nginx_replicas must be null when ingress_nginx_kind is set to 'DaemonSet'."
  }
}

variable "ingress_load_balancer_type" {
  type        = string
  default     = "lb11"
  description = "Specifies the type of load balancer to be used for the ingress. Valid options are 'lb11', 'lb21', or 'lb31'."

  validation {
    condition     = contains(["lb11", "lb21", "lb31"], var.ingress_load_balancer_type)
    error_message = "Invalid load balancer type. Allowed values are 'lb11', 'lb21', or 'lb31'."
  }
}

variable "ingress_load_balancer_algorithm" {
  type        = string
  default     = "least_connections"
  description = "Specifies the algorithm used by the ingress load balancer. 'round_robin' distributes requests evenly across all servers, while 'least_connections' directs requests to the server with the fewest active connections."

  validation {
    condition     = contains(["round_robin", "least_connections"], var.ingress_load_balancer_algorithm)
    error_message = "Invalid load balancer algorithm. Allowed values are 'round_robin' or 'least_connections'."
  }
}

variable "ingress_load_balancer_public_network_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables the public interface of the Load Balancer."
}


# Miscellaneous
variable "prometheus_operator_crds_version" {
  type        = string
  default     = "v0.77.1"
  description = "Specifies the version of the Prometheus Operator Custom Resource Definitions (CRDs) to deploy."
}
