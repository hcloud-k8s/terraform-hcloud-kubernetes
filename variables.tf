# Cluster Configuration
variable "cluster_name" {
  type        = string
  description = "Specifies the name of the cluster. This name is used to identify the cluster within the infrastructure and should be unique across all deployments."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$", var.cluster_name))
    error_message = "The cluster name must start and end with a lowercase letter or number, can contain hyphens, and must be no longer than 32 characters."
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

variable "cluster_rdns" {
  type        = string
  default     = null
  description = "Specifies the general reverse DNS FQDN for the cluster, used for internal networking and service discovery. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.cluster_rdns == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.cluster_rdns))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "cluster_rdns_ipv4" {
  type        = string
  default     = null
  description = "Defines the IPv4-specific reverse DNS FQDN for the cluster, crucial for network operations and service discovery. Supports dynamic placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.cluster_rdns_ipv4 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.cluster_rdns_ipv4))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "cluster_rdns_ipv6" {
  type        = string
  default     = null
  description = "Defines the IPv6-specific reverse DNS FQDN for the cluster, crucial for network operations and service discovery. Supports dynamic placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.cluster_rdns_ipv6 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.cluster_rdns_ipv6))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
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
    source_ips      = optional(list(string), [])
    destination_ips = optional(list(string), [])
    protocol        = string
    port            = optional(string)
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
        (rule.direction == "in" && rule.source_ips != null && (rule.destination_ips == null || length(rule.destination_ips) == 0)) ||
        (rule.direction == "out" && rule.destination_ips != null && (rule.source_ips == null || length(rule.source_ips) == 0))
      )
    ])
    error_message = "For 'in' direction, 'source_ips' must be provided and 'destination_ips' must be null or empty. For 'out' direction, 'destination_ips' must be provided and 'source_ips' must be null or empty."
  }

  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        (rule.protocol != "icmp" && rule.protocol != "gre" && rule.protocol != "esp") || (rule.port == null)
      )
    ])
    error_message = "Port must not be specified when 'protocol' is 'icmp', 'gre', or 'esp'."
  }

  // Validation to ensure port is specified for protocols that have ports
  validation {
    condition = alltrue([
      for rule in var.firewall_extra_rules : (
        rule.protocol == "tcp" || rule.protocol == "udp" ? rule.port != null : true
      )
    ])
    error_message = "Port must be specified when 'protocol' is 'tcp' or 'udp'."
  }
}

variable "firewall_api_source" {
  type        = list(string)
  default     = null
  description = "Source networks that have access to Kube and Talos API. If set, this overrides the firewall_use_current_ipv4 and firewall_use_current_ipv6 settings."
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

variable "kube_api_admission_control" {
  type        = list(any)
  default     = []
  description = "List of admission control settings for the Kube API. If set, this overrides the default admission control."
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
    rdns        = optional(string)
    rdns_ipv4   = optional(string)
    rdns_ipv6   = optional(string)
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

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Control Plane nodepool name must not exceed 56 characters."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : np.rdns == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns))
    ])
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : np.rdns_ipv4 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns_ipv4))
    ])
    error_message = "The rdns_ipv4 must be a valid IPv4 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : np.rdns_ipv6 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns_ipv6))
    ])
    error_message = "The rdns_ipv6 must be a valid IPv6 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }
}

variable "control_plane_config_patches" {
  type        = list(any)
  default     = []
  description = "List of configuration patches applied to the Control Plane nodes."
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
    rdns            = optional(string)
    rdns_ipv4       = optional(string)
    rdns_ipv6       = optional(string)
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

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Worker nodepool name must not exceed 56 characters."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : np.rdns == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns))
    ])
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : np.rdns_ipv4 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns_ipv4))
    ])
    error_message = "The rdns_ipv4 must be a valid IPv4 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : np.rdns_ipv6 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", np.rdns_ipv6))
    ])
    error_message = "The rdns_ipv6 must be a valid IPv6 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }
}

variable "worker_config_patches" {
  type        = list(any)
  default     = []
  description = "List of configuration patches applied to the Worker nodes."
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
  default     = "9.45.1"
  description = "Version of the Cluster Autoscaler Helm chart to deploy."
}

variable "cluster_autoscaler_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Cluster Autoscaler chart deployment. These values will merge with and will override the default values provided by the Cluster Autoscaler Helm chart."
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

  validation {
    condition = alltrue([
      for np in var.cluster_autoscaler_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Cluster Autoscaler nodepool name must not exceed 56 characters."
  }
}

variable "cluster_autoscaler_config_patches" {
  type        = list(any)
  default     = []
  description = "List of configuration patches applied to the Cluster Autoscaler nodes."
}


# Talos
variable "talos_version" {
  type        = string
  default     = "v1.8.4"
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
  type = list(string)
  default = [
    "ntp1.hetzner.de",
    "ntp2.hetzner.com",
    "ntp3.hetzner.net"
  ]
  description = "Specifies a list of time server addresses used for network time synchronization across the cluster. These servers ensure that all cluster nodes maintain accurate and synchronized time."
}

variable "talos_registries" {
  type        = any
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

variable "talos_service_log_destinations" {
  description = "List of objects defining remote destinations for Talos service logs."
  type = list(object({
    endpoint  = string
    format    = optional(string, "json_lines")
    extraTags = optional(map(string), {})
  }))
  default = []
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
  default     = "v1.31.4"
  description = "Specifies the Kubernetes version to deploy."
}

variable "kubernetes_kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to pass to the kubelet service. These arguments can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}

variable "kubernetes_kubelet_extra_config" {
  type        = any
  default     = {}
  description = "Specifies additional configuration settings for the kubelet service. These settings can customize or override default kubelet configurations, allowing for tailored cluster behavior."
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
  default     = "v1.9.0" # https://github.com/siderolabs/talos-cloud-controller-manager
  description = "Specifies the version of the Talos Cloud Controller Manager (CCM) to use. This version controls cloud-specific integration features in the Talos operating system."
}


# Hetzner Cloud
variable "hcloud_token" {
  type        = string
  description = "The Hetzner Cloud API token used for authentication with Hetzner Cloud services. This token should be treated as sensitive information."
  sensitive   = true
}

variable "hcloud_network" {
  type = object({
    id = number
  })
  default     = null
  description = "The Hetzner network resource of an existing network."
}

variable "hcloud_network_id" {
  type        = number
  default     = null
  description = "The Hetzner network ID of an existing network."

  validation {
    condition     = !(var.hcloud_network_id != null && var.hcloud_network != null)
    error_message = "Only one of hcloud_network_id or hcloud_network may be provided, not both."
  }
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


# Hetzner Cloud Controller Manager (CCM)
variable "hcloud_ccm_helm_repository" {
  type        = string
  default     = "https://charts.hetzner.cloud"
  description = "URL of the Helm repository where the Hcloud CCM chart is located."
}

variable "hcloud_ccm_helm_chart" {
  type        = string
  default     = "hcloud-cloud-controller-manager"
  description = "Name of the Helm chart used for deploying Hcloud CCM."
}

variable "hcloud_ccm_helm_version" {
  type        = string
  default     = "1.24.0"
  description = "Version of the Hcloud CCM Helm chart to deploy."
}

variable "hcloud_ccm_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Hcloud CCM chart deployment. These values will merge with and will override the default values provided by the Hcloud CCM Helm chart."
}


# Hetzner Cloud Container Storage Interface (CSI)
variable "hcloud_csi_helm_repository" {
  type        = string
  default     = "https://charts.hetzner.cloud"
  description = "URL of the Helm repository where the Hcloud CSI chart is located."
}

variable "hcloud_csi_helm_chart" {
  type        = string
  default     = "hcloud-csi"
  description = "Name of the Helm chart used for deploying Hcloud CSI."
}

variable "hcloud_csi_helm_version" {
  type        = string
  default     = "2.13.0"
  description = "Version of the Hcloud CSI Helm chart to deploy."
}

variable "hcloud_csi_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Hcloud CSI chart deployment. These values will merge with and will override the default values provided by the Hcloud CSI Helm chart."
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
  default     = "1.8.1"
  description = "Version of the Longhorn Helm chart to deploy."
}

variable "longhorn_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Longhorn chart deployment. These values will merge with and will override the default values provided by the Longhorn Helm chart."
}

variable "longhorn_enabled" {
  type        = bool
  default     = false
  description = "Enable or disable Longhorn integration"
}


# Cilium
variable "cilium_helm_repository" {
  type        = string
  default     = "https://helm.cilium.io"
  description = "URL of the Helm repository where the Cilium chart is located."
}

variable "cilium_helm_chart" {
  type        = string
  default     = "cilium"
  description = "Name of the Helm chart used for deploying Cilium."
}

variable "cilium_helm_version" {
  type        = string
  default     = "1.17.2"
  description = "Version of the Cilium Helm chart to deploy."
}

variable "cilium_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Cilium chart deployment. These values will merge with and will override the default values provided by the Cilium Helm chart."
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
  type        = any
  default     = {}
  description = "Custom Helm values for the Metrics Server chart deployment. These values will merge with and will override the default values provided by the Metrics Server Helm chart."
}

variable "metrics_server_enabled" {
  type        = bool
  default     = true
  description = "Enables the the Kubernetes Metrics Server."
}

variable "metrics_server_schedule_on_control_plane" {
  type        = bool
  default     = null
  description = "Determines whether to schedule the Metrics Server on control plane nodes. Defaults to 'true' if there are no configured worker nodes."
}

variable "metrics_server_replicas" {
  type        = number
  default     = null
  description = "Specifies the number of replicas for the Metrics Server. Depending on the node pool size, a default of 1 or 2 is used if not explicitly set."
}


# Cert Manager
variable "cert_manager_helm_repository" {
  type        = string
  default     = "https://charts.jetstack.io"
  description = "URL of the Helm repository where the Cert Manager chart is located."
}

variable "cert_manager_helm_chart" {
  type        = string
  default     = "cert-manager"
  description = "Name of the Helm chart used for deploying Cert Manager."
}

variable "cert_manager_helm_version" {
  type        = string
  default     = "v1.17.1"
  description = "Version of the Cert Manager Helm chart to deploy."
}

variable "cert_manager_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Cert Manager chart deployment. These values will merge with and will override the default values provided by the Cert Manager Helm chart."
}

variable "cert_manager_enabled" {
  type        = bool
  default     = false
  description = "Enables the deployment of cert-manager for managing TLS certificates."
}


# Ingress NGINX
variable "ingress_nginx_helm_repository" {
  type        = string
  default     = "https://kubernetes.github.io/ingress-nginx"
  description = "URL of the Helm repository where the Ingress NGINX Controller chart is located."
}

variable "ingress_nginx_helm_chart" {
  type        = string
  default     = "ingress-nginx"
  description = "Name of the Helm chart used for deploying Ingress NGINX Controller."
}

variable "ingress_nginx_helm_version" {
  type        = string
  default     = "4.12.1"
  description = "Version of the Ingress NGINX Controller Helm chart to deploy."
}

variable "ingress_nginx_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Ingress NGINX Controller chart deployment. These values will merge with and will override the default values provided by the Ingress NGINX Controller Helm chart."
}

variable "ingress_nginx_enabled" {
  type        = bool
  default     = false
  description = "Enables the deployment of the Ingress NGINX Controller. Requires cert_manager_enabled to be true."

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
  description = "Specifies the number of replicas for the NGINX Ingress controller. If not set, the default is 2 replicas for clusters with fewer than 3 Worker nodes, and 3 replicas for clusters with 4 or more Worker nodes."

  validation {
    condition     = var.ingress_nginx_kind != "DaemonSet" || var.ingress_nginx_replicas == null
    error_message = "ingress_nginx_replicas must be null when ingress_nginx_kind is set to 'DaemonSet'."
  }
}

variable "ingress_nginx_topology_aware_routing" {
  type        = bool
  default     = false
  description = "Enables Topology Aware Routing for ingress-nginx with the service annotation `service.kubernetes.io/topology-mode`, routing traffic closer to its origin."
}

variable "ingress_nginx_service_external_traffic_policy" {
  type        = string
  default     = "Cluster"
  description = "Denotes if this Service desires to route external traffic to node-local or cluster-wide endpoints."

  validation {
    condition     = contains(["Cluster", "Local"], var.ingress_nginx_service_external_traffic_policy)
    error_message = "Invalid value for external traffic policy. Allowed values are 'Cluster' or 'Local'."
  }
}

variable "ingress_nginx_config" {
  type        = any
  default     = {}
  description = "Global configuration passed to the ConfigMap consumed by the nginx controller. (Reference: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/)"
}


# Ingress Load Balancer
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

variable "ingress_load_balancer_health_check_interval" {
  type        = number
  default     = 3
  description = "The interval (in seconds) between consecutive health checks. Must be between 3 and 60 seconds."

  validation {
    condition = (
      var.ingress_load_balancer_health_check_interval >= 3 &&
      var.ingress_load_balancer_health_check_interval <= 60
    )
    error_message = "The health check interval must be between 3 and 60 seconds."
  }
}

variable "ingress_load_balancer_health_check_retries" {
  type        = number
  default     = 3
  description = "The number of retries for a failed health check before marking the target as unhealthy. Must be between 0 and 5."

  validation {
    condition = (
      var.ingress_load_balancer_health_check_retries >= 0 &&
      var.ingress_load_balancer_health_check_retries <= 5
    )
    error_message = "The health check retries must be between 0 and 5."
  }
}

variable "ingress_load_balancer_health_check_timeout" {
  type        = number
  default     = 3
  description = "The timeout (in seconds) for each health check attempt. It cannot exceed the interval and must be a positive value."

  validation {
    condition = (
      var.ingress_load_balancer_health_check_timeout > 0 &&
      var.ingress_load_balancer_health_check_timeout <= var.ingress_load_balancer_health_check_interval
    )
    error_message = "The health check timeout must be a positive number and cannot exceed the interval."
  }
}

variable "ingress_load_balancer_rdns" {
  type        = string
  default     = null
  description = "Specifies the general reverse DNS FQDN for the ingress load balancer, used for internal networking and service discovery. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.ingress_load_balancer_rdns == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.ingress_load_balancer_rdns))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "ingress_load_balancer_rdns_ipv4" {
  type        = string
  default     = null
  description = "Defines the IPv4-specific reverse DNS FQDN for the ingress load balancer, crucial for network operations and service discovery. Supports dynamic placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.ingress_load_balancer_rdns_ipv4 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.ingress_load_balancer_rdns_ipv4))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "ingress_load_balancer_rdns_ipv6" {
  type        = string
  default     = null
  description = "Defines the IPv6-specific reverse DNS FQDN for the ingress load balancer, crucial for network operations and service discovery. Supports dynamic placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."

  validation {
    condition     = var.ingress_load_balancer_rdns_ipv6 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", var.ingress_load_balancer_rdns_ipv6))
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "ingress_load_balancer_pools" {
  type = list(object({
    name                    = string
    location                = string
    type                    = optional(string)
    labels                  = optional(map(string), {})
    count                   = optional(number, 1)
    target_label_selector   = optional(list(string), [])
    local_traffic           = optional(bool, false)
    load_balancer_algorithm = optional(string)
    public_network_enabled  = optional(bool)
    rdns                    = optional(string)
    rdns_ipv4               = optional(string)
    rdns_ipv6               = optional(string)
  }))
  default     = []
  description = "Defines configuration settings for Ingress Load Balancer pools within the cluster."

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : contains([
        "fsn1", "nbg1", "hel1", "ash", "hil", "sin"
      ], pool.location)
    ])
    error_message = "Each Load Balancer location must be one of: 'fsn1' (Falkenstein), 'nbg1' (Nuremberg), 'hel1' (Helsinki), 'ash' (Ashburn), 'hil' (Hillsboro), 'sin' (Singapore)."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : (
        pool.type == null || contains(
          ["lb11", "lb21", "lb31"],
          coalesce(pool.type, var.ingress_load_balancer_type)
        )
      )
    ])
    error_message = "Invalid Load Balancer type specified. Allowed values are 'lb11', 'lb21', or 'lb31'. If not specified, the default ingress_load_balancer_type will be used."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools :
      pool.load_balancer_algorithm == null || contains(
        ["round_robin", "least_connections"],
        coalesce(pool.load_balancer_algorithm, var.ingress_load_balancer_algorithm)
      )
    ])
    error_message = "Invalid Load Balancer algorithm specified. Allowed values are 'round_robin' or 'least_connections'. If not specified, the default ingress_load_balancer_algorithm will be used."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : length(var.cluster_name) + length(pool.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Load Balancer pool name must not exceed 56 characters."
  }

  validation {
    condition     = length(var.ingress_load_balancer_pools) == length(distinct([for pool in var.ingress_load_balancer_pools : pool.name]))
    error_message = "Duplicate Load Balancer pool names are not allowed. Each pool name must be unique."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : pool.rdns == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", pool.rdns))
    ])
    error_message = "The reverse DNS domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : pool.rdns_ipv4 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", pool.rdns_ipv4))
    ])
    error_message = "The rdns_ipv4 must be a valid IPv4 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }

  validation {
    condition = alltrue([
      for pool in var.ingress_load_balancer_pools : pool.rdns_ipv6 == null || can(regex("^(?:(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?\\.)*(?:[a-z0-9{} ](?:[a-z0-9-{} ]{0,61}[a-z0-9{} ])?))$", pool.rdns_ipv6))
    ])
    error_message = "The rdns_ipv6 must be a valid IPv6 reverse DNS domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters. Supports dynamic substitution with placeholders: {{ cluster-domain }}, {{ cluster-name }}, {{ hostname }}, {{ id }}, {{ ip-labels }}, {{ ip-type }}, {{ pool }}, {{ role }}."
  }
}


# Miscellaneous
variable "prometheus_operator_crds_version" {
  type        = string
  default     = "v0.81.0" # https://github.com/prometheus-operator/prometheus-operator
  description = "Specifies the version of the Prometheus Operator Custom Resource Definitions (CRDs) to deploy."
}
