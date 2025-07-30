<div align="center">

  <img src="https://avatars.githubusercontent.com/u/182015181" alt="logo" width="225" height="auto" />
  <h1>Hcloud Kubernetes</h1>

  <p>
    Terraform Module to deploy Kubernetes on Hetzner Cloud! 
  </p>

<!-- Badges -->
<p>
  <a href="">
    <img src="https://img.shields.io/github/release/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="last update" />
  </a>
  <a href="">
    <img src="https://img.shields.io/github/last-commit/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="last update" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/network/members">
    <img src="https://img.shields.io/github/forks/hcloud-k8s/terraform-hcloud-kubernetes" alt="forks" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/stargazers">
    <img src="https://img.shields.io/github/stars/hcloud-k8s/terraform-hcloud-kubernetes" alt="stars" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/issues/">
    <img src="https://img.shields.io/github/issues/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="open issues" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="license" />
  </a>
</p>

</div>

<br />

<!-- Table of Contents -->
# :notebook_with_decorative_cover: Table of Contents
- [:star2: About the Project](#star2-about-the-project)
- [:rocket: Getting Started](#rocket-getting-started)
- [:hammer_and_pick: Advanced Configuration](#hammer_and_pick-advanced-configuration)
- [:recycle: Lifecycle](#recycle-lifecycle)
- [:compass: Roadmap](#compass-roadmap)

<!-- About the Project -->
## :star2: About the Project
Hcloud Kubernetes is a Terraform module for deploying a fully declarative, managed Kubernetes cluster on Hetzner Cloud. It utilizes Talos, a secure, immutable, and minimal operating system specifically designed for Kubernetes, featuring a streamlined architecture with only a handful of binaries and shared libraries. Just enough to run containerd and a small set of system services.

This project is committed to production-grade configuration and lifecycle management, ensuring all components are set up for high availability. It includes a curated selection of widely used and officially recognized Kubernetes components. If you encounter any issues, suboptimal settings, or missing elements, please file an [issue](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/issues) to help us improve this project.

> [!TIP]
> If you don't yet have a Hetzner account, feel free to use this [Hetzner Cloud Referral Link](https://hetzner.cloud/?ref=GMylKeDmqtsD) to claim a €20 credit and support this project.

<!-- Features -->
### :sparkles: Features

This setup includes several features for a seamless, best-practice Kubernetes deployment on Hetzner Cloud:
- **Fully Declarative & Immutable:** Utilize Talos Linux for a completely declarative and immutable Kubernetes setup on Hetzner Cloud.
- **Cross-Architecture:** Supports both AMD64 and ARM64 architectures, with integrated image upload to Hetzner Cloud.
- **High Availability:** Configured for production-grade high availability for all components, ensuring consistent and reliable system performance.
- **Distributed Storage:** Implements Longhorn for cloud-native block storage with snapshotting and automatic replica rebuilding.
- **Autoscaling:** Includes Cluster Autoscaler to dynamically adjust node counts based on workload demands, optimizing resource allocation.
- **Plug-and-Play Kubernetes:** Equipped with an optional Ingress Controller and Cert Manager, facilitating rapid workload deployment.
- **Geo-Redundant Ingress:** Supports high availability and massive scalability through geo-redundant Load Balancer pools.
- **Dual-Stack Support:** Employs Load Balancers with Proxy Protocol to efficiently route both IPv4 and IPv6 traffic to the Ingress Controller.
- **Enhanced Security:** Built with security as a priority, incorporating firewalls and encryption by default to protect your infrastructure.
- **Automated Backups:** Leverages Talos Backup with support for S3-compatible storage solutions like Hetzner's Object Storage.

<!-- Components -->
### :package: Components
This project includes commonly used and essential Kubernetes software, optimized for seamless integration with Hetzner Cloud.

- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=talos.dev&sz=32" width="16" height="16">
    <b><a href="https://github.com/siderolabs/talos-cloud-controller-manager">Talos Cloud Controller Manager (CCM)</a></b>
  </summary>
  Manages node resources by updating with cloud metadata, handling lifecycle deletions, and automatically approving node CSRs.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=talos.dev&sz=32" width="16" height="16">
    <b><a href="https://github.com/siderolabs/talos-backup">Talos Backup</a></b>
  </summary>
  Automates etcd snapshots and S3 storage for backup in Talos Linux-based Kubernetes clusters.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=hetzner.com&sz=32" width="16" height="16">
    <b><a href="https://github.com/hetznercloud/hcloud-cloud-controller-manager">Hcloud Cloud Controller Manager (CCM)</a></b>
  </summary>
  Manages the integration of Kubernetes clusters with Hetzner Cloud services, ensuring the update of node data, private network traffic control, and load balancer setup.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=hetzner.com&sz=32" width="16" height="16">
    <b><a href="https://github.com/hetznercloud/csi-driver">Hcloud Container Storage Interface (CSI)</a></b>
  </summary>
  Manages persistent storage in Kubernetes clusters using Hetzner Cloud Volumes, ensuring seamless storage integration and management.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=longhorn.io&sz=32" width="16" height="16">
    <b><a href="https://longhorn.io">Longhorn</a></b>
  </summary>
  Delivers distributed block storage for Kubernetes, facilitating high availability and easy management of persistent volumes with features like snapshotting and automatic replica rebuilding.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=cilium.io&sz=32" width="16" height="16">
    <b><a href="https://cilium.io">Cilium Container Network Interface (CNI)</a></b>
  </summary>
  A high performance CNI plugin that enhances and secures network connectivity and observability for container workloads through the use of eBPF technology in Linux kernels.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=nginx.org&sz=32" width="16" height="16">
    <b><a href="https://kubernetes.github.io/ingress-nginx/">Ingress NGINX Controller</a></b>
  </summary>
  Provides a robust web routing and load balancing solution for Kubernetes, utilizing NGINX as a reverse proxy to manage traffic and enhance network performance.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=cert-manager.io&sz=32" width="16" height="16">
    <b><a href="https://cert-manager.io">Cert Manager</a></b>
  </summary>
  Automates the management of certificates in Kubernetes, handling the issuance and renewal of certificates from various sources like Let's Encrypt, and ensures certificates are valid and updated.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=kubernetes.io&sz=32" width="16" height="16">
    <b><a href="https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler">Cluster Autoscaler</a></b>
  </summary>
  Dynamically adjusts Kubernetes cluster size based on resource demands and node utilization, scaling nodes in or out to optimize cost and performance.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=kubernetes.io&sz=32" width="16" height="16">
    <b><a href="https://kubernetes-sigs.github.io/metrics-server/">Metrics Server</a></b>
  </summary>
  Collects and provides container resource metrics for Kubernetes, enabling features like autoscaling by interacting with Horizontal and Vertical Pod Autoscalers.

<!-- Security -->
### :shield: Security
Talos Linux is a secure, minimal, and immutable OS for Kubernetes, removing SSH and shell access to reduce attack surfaces. Managed through a secure API with mTLS, Talos prevents configuration drift, enhancing both security and predictability. It follows [NIST](https://www.nist.gov/publications/application-container-security-guide) and [CIS](https://www.cisecurity.org/benchmark/kubernetes) hardening standards, operates in memory, and is built to support modern, production-grade Kubernetes environments.

**Firewall Protection:** This module uses [Hetzner Cloud Firewalls](https://docs.hetzner.com/cloud/firewalls/) to manage external access to nodes. For internal pod-to-pod communication, support for Kubernetes Network Policies is provided through [Cilium CNI](https://docs.cilium.io/en/stable/network/kubernetes/policy/).

**Encryption in Transit:** In this module, all pod network traffic is encrypted by default using [WireGuard (Default) or IPSec via Cilium CNI](https://cilium.io/use-cases/transparent-encryption/). It includes automatic key rotation and efficient in-kernel encryption, covering all traffic types.

**Encryption at Rest:** In this module, the [STATE](https://www.talos.dev/latest/learn-more/architecture/#file-system-partitions) and [EPHEMERAL](https://www.talos.dev/latest/learn-more/architecture/#file-system-partitions) partitions are encrypted by default with [Talos Disk Encryption](https://www.talos.dev/latest/talos-guides/configuration/disk-encryption/) using LUKS2. Each node is secured with individual encryption keys derived from its unique `nodeID`.

<!-- Getting Started -->
## 	:rocket: Getting Started

<!-- Prerequisites -->
### :heavy_check_mark: Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/install) or [tofu](https://opentofu.org/docs/intro/install/) to deploy the Cluster
- [packer](https://developer.hashicorp.com/packer/install) to upload Talos Images
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl/) to control the Talos Cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) to control Kubernetes (optional)

> [!IMPORTANT]
> Keep the CLI tools up to date. Ensure that `talosctl` matches your Talos version for compatibility, especially before a Talos upgrade.

<!-- Installation -->
### :dart: Installation

Create `kubernetes.tf` file with the module configuration:
```hcl
module "kubernetes" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "<version>"

  cluster_name = "k8s"
  hcloud_token = "<hcloud-token>"

  # Export configs for Talos and Kube API access
  cluster_kubeconfig_path  = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  # Optional Ingress Controller and Cert Manager
  cert_manager_enabled  = true
  ingress_nginx_enabled = true

  control_plane_nodepools = [
    { name = "control", type = "cpx21", location = "fsn1", count = 3 }
  ]
  worker_nodepools = [
    { name = "worker", type = "cpx11", location = "fsn1", count = 3 }
  ]
}
```
> [!NOTE]
> Each Control Plane node requires at least 4GB of memory and each Worker node at least 2GB. For High-Availability (HA), at least 3 Control Plane nodes and 3 Worker nodes are required.

Initialize and deploy the cluster:

**Terraform:**
```sh
terraform init -upgrade
terraform apply
```
**OpenTofu:**
```sh
tofu init -upgrade
tofu apply
```

<!-- Cluster Access -->
### :key: Cluster Access

Set config file locations:
```sh
export TALOSCONFIG=talosconfig
export KUBECONFIG=kubeconfig
```

Display cluster nodes:
```sh
talosctl get member
kubectl get nodes -o wide
```

Display all pods:
```sh
kubectl get pods -A
```

For more detailed information and examples, please visit:
- [Talos CLI Documentation](https://www.talos.dev/latest/reference/cli/)
- [Kubernetes CLI Documentation](https://kubernetes.io/docs/reference/kubectl/introduction/)

### :boom: Teardown
To destroy the cluster, first disable the delete protection by setting:
```hcl
cluster_delete_protection = false
```

Apply this change before proceeding. Once the delete protection is disabled, you can teardown the cluster.

**Terraform:**
```sh
terraform state rm 'module.kubernetes.talos_machine_configuration_apply.worker'
terraform state rm 'module.kubernetes.talos_machine_configuration_apply.control_plane'
terraform state rm 'module.kubernetes.talos_machine_secrets.this'
terraform destroy
```
**OpenTofu:**
```sh
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.worker'
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.control_plane'
tofu state rm 'module.kubernetes.talos_machine_secrets.this'
tofu destroy
```

<!-- Advanced Configuration -->
## :hammer_and_pick: Advanced Configuration

<!-- Cluster Access -->
<details>
<summary><b>Cluster Access</b></summary>

#### Public Cluster Access
By default, the cluster is accessible over the public internet. The firewall is automatically configured to use the IPv4 address and /64 IPv6 CIDR of the machine running this module. To disable this automatic configuration, set the following variables to `false`:

```hcl
firewall_use_current_ipv4 = false
firewall_use_current_ipv6 = false
```

To manually specify source networks for the Talos API and Kube API, configure the `firewall_api_source` variable as follows:
```hcl
firewall_api_source = [
  "1.2.3.0/32",
  "1:2:3::/64"
]
```
This allows explicit control over which networks can access your APIs, overriding the default behavior when set.

#### Internal Cluster Access
If your internal network is routed and accessible, you can directly access the cluster using internal IPs by setting:
```hcl
cluster_access = "private"
```

For integrating Talos nodes with an internal network, configure a default route (`0.0.0.0/0`) in the Hetzner Network to point to your router or gateway. Additionally, add specific routes on the Talos nodes to encompass your entire network CIDR:
```hcl
talos_extra_routes = ["10.0.0.0/8"]

# Optionally, disable NAT for your globally routed CIDR
network_native_routing_cidr = "10.0.0.0/8"

# Optionally, use an existing Network
hcloud_network_id = 123456789
```
This setup ensures that the Talos nodes can route traffic appropriately across your internal network.


#### Access to Kubernetes API

Optionally, a hostname can be configured to direct access to the Kubernetes API through a node IP, load balancer, or Virtual IP (VIP):
```hcl
kube_api_hostname = "kube-api.example.com"
```

##### Access from Public Internet
For accessing the Kubernetes API from the public internet, choose one of the following options based on your needs:
1. **Use a Load Balancer (Recommended):**<br>
    Deploy a load balancer to manage API traffic, enhancing availability and load distribution.
    ```hcl
    kube_api_load_balancer_enabled = true
    ```
2. **Use a Virtual IP (Floating IP):**<br>
    A Floating IP is configured to automatically move between control plane nodes in case of an outage, ensuring continuous access to the Kubernetes API.
    ```hcl
    control_plane_public_vip_ipv4_enabled = true

    # Optionally, specify an existing Floating IP
    control_plane_public_vip_ipv4_id = 123456789
    ```

##### Access from Internal Network
When accessing the Kubernetes API via an internal network, an internal Virtual IP (Alias IP) is utilized by default to route API requests within the network. This feature can be disabled with the following configuration:
```hcl
control_plane_private_vip_ipv4_enabled = false
```

To enhance internal availability, a load balancer can be used:
```hcl
kube_api_load_balancer_enabled = true
```

This setup ensures secure and flexible access to the Kubernetes API, accommodating different networking environments.
</details>

<!-- Cluster Autoscaler -->
<details>
<summary><b>Cluster Autoscaler</b></summary>
The Cluster Autoscaler dynamically adjusts the number of nodes in a Kubernetes cluster based on the demand, ensuring that there are enough nodes to run all pods and no unneeded nodes when the workload decreases.

Example `kubernetes.tf` snippet:
```hcl
# Configuration for cluster autoscaler node pools
cluster_autoscaler_nodepools = [
  {
    name     = "autoscaler"
    type     = "cpx11"
    location = "fsn1"
    min      = 0
    max      = 6
    labels   = { "autoscaler-node" = "true" }
    taints   = [ "autoscaler-node=true:NoExecute" ]
  }
]
```

Optionally, pass additional [Helm values](https://github.com/kubernetes/autoscaler/blob/master/charts/cluster-autoscaler/values.yaml) to the cluster autoscaler configuration:
```hcl
cluster_autoscaler_helm_values = {
  extraArgs = {
    enforce-node-group-min-size   = true
    scale-down-delay-after-add    = "45m"
    scale-down-delay-after-delete = "4m"
    scale-down-unneeded-time      = "5m"
  }
}
```
</details>


<!-- Cilium Advanced Configuration -->
<details>
<summary><b>Cilium Advanced Configuration</b></summary>

#### Cilium Transparent Encryption

This module enables [Cilium Transparent Encryption](https://cilium.io/use-cases/transparent-encryption/) feature by default.  

All pod network traffic is encrypted using WireGuard (Default) or  protocols, includes automatic key rotation and efficient in-kernel encryption, covering all traffic types.

:bulb: Although WireGuard is the default option, Hetzner Cloud VMs supports AES-NI instruction set, making IPSec encryption more CPU-efficient compared to WireGuard. Consider enabling IPSec for CPU savings through hardware acceleration.

IPSec mode supports RFC4106 AES-GCM encryption with 128, 192 and 256 bits key sizes.


**:warning: IPSec encryption has the following limitations:**

- No transparent encryption when chaining Cilium with other CNI plugins
- Host Policies not supported with IPSec
- Incompatible with BPF Host Routing (automatically disabled on switch)
- IPv6-only clusters not supported
- Maximum 65,535 nodes per cluster/clustermesh
- Single CPU core limitation per IPSec tunnel may affect high-throughput scenarios

*Source: [Cilium Documentation](https://docs.cilium.io/en/stable/security/network/encryption-ipsec/#limitations)*

Example `kubernetes.tf` configuration:

```hcl
cilium_encryption_enabled = true                # Default true
cilium_encryption_type    = "wireguard"         # wireguard (Default) | ipsec
cilium_ipsec_algorithm    = "rfc4106(gcm(aes))" # IPSec AES key algorithm (Default rfc4106(gcm(aes)))
cilium_ipsec_key_size     = 256                 # IPSec AES key size (Default 256)
cilium_ipsec_key_id       = 1                   # IPSec key ID (Default 1)
```

##### IPSec Key Rotation

Keys automatically rotate when `cilium_ipsec_key_id` is incremented (1-15 range, resets to 1 after 15).

</details>

<!-- Egress Gateway -->
<details>
<summary><b>Egress Gateway</b></summary>

Cilium offers an Egress Gateway to ensure network compatibility with legacy systems and firewalls requiring fixed IPs. The use of Cilium Egress Gateway does not provide high availability and increases latency due to extra network hops and tunneling. Consider this configuration only as a last resort.

Example `kubernetes.tf` snippet:
```hcl
# Enable Cilium Egress Gateway
cilium_egress_gateway_enabled = true

# Define worker nodepools including an egress-specific node pool
worker_nodepools = [
  # ... (other node pool configurations)
  {
    name     = "egress"
    type     = "cpx11"
    location = "fsn1"
    labels   = { "egress-node" = "true" }
    taints   = [ "egress-node=true:NoSchedule" ]
  }
]
```

Example Egress Gateway Policy:
```yml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: sample-egress-policy
spec:
  selectors:
    - podSelector:
        matchLabels:
          io.kubernetes.pod.namespace: sample-namespace
          app: sample-app

  destinationCIDRs:
    - "0.0.0.0/0"

  egressGateway:
    nodeSelector:
      matchLabels:
        egress-node: "true"
```

Please visit the Cilium [documentation](https://docs.cilium.io/en/stable/network/egress-gateway) for more details.
</details>

<!-- Firewall Configuration -->
<details>
<summary><b>Firewall Configuration</b></summary>
By default, a firewall is configured that can be extended with custom rules. If no egress rules are configured, outbound traffic remains unrestricted. However, inbound traffic is always restricted to mitigate the risk of exposing Talos nodes to the public internet, which could pose a serious security vulnerability.

Each rule is defined with the following properties:
- `description`: A brief description of the rule.
- `direction`: The direction of traffic (`in` for inbound, `out` for outbound).
- `source_ips`: A list of source IP addresses for outbound rules.
- `destination_ips`: A list of destination IP addresses for inbound rules.
- `protocol`: The protocol used (valid options: `tcp`, `udp`, `icmp`, `gre`, `esp`).
- `port`: The port number (required for `tcp` and `udp` protocols, must not be specified for `icmp`, `gre`, and `esp`).

Example `kubernetes.tf` snippet:
```hcl
firewall_extra_rules = [
  {
    description = "Custom UDP Rule"
    direction   = "in"
    source_ips  = ["0.0.0.0/0", "::/0"]
    protocol    = "udp"
    port        = "12345"
  },
  {
    description = "Custom TCP Rule"
    direction   = "in"
    source_ips  = ["1.2.3.4", "1:2:3:4::"]
    protocol    = "tcp"
    port        = "8080-9000"
  },
  {
    description = "Allow ICMP"
    direction   = "in"
    source_ips  = ["0.0.0.0/0", "::/0"]
    protocol    = "icmp"
  }
]
```

For access to Talos and the Kubernetes API, please refer to the [Cluster Access](#public-cluster-access) configuration section.

</details>

<!-- Ingress Load Balancer -->
<details>
<summary><b>Ingress Load Balancer</b></summary>

The ingress controller uses a default load balancer service to manage external traffic. For geo-redundancy and high availability, `ingress_load_balancer_pools` can be configured as an alternative, replacing the default load balancer with the specified pool of load balancers.

##### Configuring Load Balancer Pools
To replace the default load balancer, use `ingress_load_balancer_pools` in the Terraform configuration. This setup ensures high availability and geo-redundancy by distributing traffic from various locations across all targets in all regions.

Example `kubernetes.tf` configuration:
```hcl
ingress_load_balancer_pools = [
  {
    name     = "lb-nbg"
    location = "nbg1"
    type     = "lb11"
  },
  {
    name     = "lb-fsn"
    location = "fsn1"
    type     = "lb11"
  }
]
```

##### Local Traffic Optimization
Configuring local traffic handling enhances network efficiency by reducing latency. Processing traffic closer to its source eliminates unnecessary routing delays, ensuring consistent performance for low-latency or region-sensitive applications.

Example `kubernetes.tf` configuration:
```hcl
ingress_nginx_kind = "DaemonSet"
ingress_nginx_service_external_traffic_policy = "Local"

ingress_load_balancer_pools = [
  {
    name          = "regional-lb-nbg"
    location      = "nbg1"
    local_traffic = true
  },
  {
    name          = "regional-lb-fsn"
    location      = "fsn1"
    local_traffic = true
  }
]
```

Key settings in this configuration:
- `local_traffic`: Limits load balancer targets to nodes in the same geographic location as the load balancer, reducing data travel distances and keeping traffic within the region.
- `ingress_nginx_service_external_traffic_policy` set to `Local`: Ensures external traffic is handled directly on the local node, avoiding extra network hops.
- `ingress_nginx_kind` set to `DaemonSet`: Deploys an ingress controller instance on every node, enabling requests to be handled locally for faster response times.

Topology-aware routing in ingress-nginx can optionally be enabled by setting the `ingress_nginx_topology_aware_routing` variable to `true`. This functionality routes traffic to the nearest upstream endpoints, enhancing efficiency for supported services. Note that this feature is only applicable to services that support topology-aware routing. For more information, refer to the [Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing/).

</details>

<!-- Network Segmentation -->
<details>
<summary><b>Network Segmentation</b></summary>

By default, this module calculates optimal subnets based on the provided network CIDR (`network_ipv4_cidr`). The network is segmented automatically as follows:

- **1st Quarter**: Reserved for other uses such as classic VMs.
- **2nd Quarter**:
  - **1st Half**: Allocated for Node Subnets (`network_node_ipv4_cidr`)
  - **2nd Half**: Allocated for Service IPs (`network_service_ipv4_cidr`)
- **3rd and 4th Quarters**:
  - **Full Span**: Allocated for Pod Subnets (`network_pod_ipv4_cidr`)

Each Kubernetes node requires a `/24` subnet within `network_pod_ipv4_cidr`. To support this configuration, the optimal node subnet size (`network_node_ipv4_subnet_mask_size`) is calculated using the formula:<br>
32 - (24 - subnet_mask_size(`network_pod_ipv4_cidr`)).

With the default `10.0.0.0/16` network CIDR (`network_ipv4_cidr`), the following values are calculated:
- **Node Subnet Size**: `/25` (Max. 128 Nodes per Subnet)
- **Node Subnets**: `10.0.64.0/19` (Max. 64 Subnets, each with `/25`)
- **Service IPs**: `10.0.96.0/19` (Max. 8192 Services)
- **Pod Subnet Size**: `/24` (Max. 256 Pods per Node)
- **Pod Subnets**: `10.0.128.0/17` (Max. 128 Nodes, each with `/24`)

Please consider the following Hetzner Cloud limits:
- Up to **100 servers** can be attached to a network.
- Up to **100 routes** can be created per network.
- Up to **50 subnets** can be created per network.
- A project can have up to **50 placement groups**.

A `/16` Network CIDR is sufficient to fully utilize Hetzner Cloud's scaling capabilities. It supports:
- Up to 100 nodes, each with its own `/24` Pod subnet route.
- Configuration of up to 50 nodepools, one nodepool per subnet, each with at least one placement group.


Here is a table with more example calculations:
| Network CIDR    | Node Subnet Size | Node Subnets      | Service IPs         | Pod Subnets         |
| --------------- | ---------------- | ----------------- | ------------------- | ------------------- |
| **10.0.0.0/16** | /25 (128 IPs)    | 10.0.64.0/19 (64) | 10.0.96.0/19 (8192) | 10.0.128.0/17 (128) |
| **10.0.0.0/17** | /26 (64 IPs)     | 10.0.32.0/20 (64) | 10.0.48.0/20 (4096) | 10.0.64.0/18 (64)   |
| **10.0.0.0/18** | /27 (32 IPs)     | 10.0.16.0/21 (64) | 10.0.24.0/21 (2048) | 10.0.32.0/19 (32)   |
| **10.0.0.0/19** | /28 (16 IPs)     | 10.0.8.0/22  (64) | 10.0.12.0/22 (1024) | 10.0.16.0/20 (16)   |
| **10.0.0.0/20** | /29 (8 IPs)      | 10.0.4.0/23  (64) | 10.0.6.0/23 (512)   | 10.0.8.0/21 (8)     |
| **10.0.0.0/21** | /30 (4 IPs)      | 10.0.2.0/24  (64) | 10.0.3.0/24 (256)   | 10.0.4.0/22 (4)     |
 
</details>


<!-- Storage Configuration-->
<details>
<summary><b>Storage Configuration</b></summary>

#### Hetzner Cloud CSI

The Hetzner Cloud Container Storage Interface (CSI) driver can be flexibly configured through the `hcloud_csi_storage_classes` variable. You can define multiple storage classes for your cluster:

* **name:** The name of the StorageClass (string, required).
* **encrypted:** Enable LUKS encryption for volumes (bool, required).
* **defaultStorageClass:** Set this class as the default (optional, bool, defaults to `false`).
* **reclaimPolicy:** The Kubernetes reclaim policy (`Delete` or `Retain`, optional, defaults to `Delete`).
* **extraParameters:** Additional parameters for the StorageClass (optional map).

**Example:**

```hcl
hcloud_csi_storage_classes = [
  {
    name                = "hcloud-volumes"
    encrypted           = false
    defaultStorageClass = true
  },
  {
    name                = "hcloud-volumes-encrypted-xfs"
    encrypted           = true
    reclaimPolicy       = "Retain"
    extraParameters     = {
      "csi.storage.k8s.io/fstype" = "xfs"
      "fsFormatOption"            = "-i nrext64=1"
    }
  }
]
```

**Other settings:**

* **hcloud\_csi\_encryption\_passphrase:**
  Optionally provide a custom encryption passphrase for LUKS-encrypted storage classes.

  ```hcl
  hcloud_csi_encryption_passphrase = "<secret-passphrase>"
  ```

**Storage Class Immutability:**
StorageClasses created by the Hcloud CSI driver are immutable. To change parameters after creation, you must either edit the StorageClass directly with `kubectl`, or delete it from both Terraform state and Kubernetes, then let this module recreate it.

For more details, see the [HCloud CSI Driver documentation](https://github.com/hetznercloud/csi-driver/tree/main/docs/kubernetes).


#### Longhorn

Longhorn is a lightweight, reliable, and easy-to-use distributed block storage system for Kubernetes.
It is fully independent from the Hetzner Cloud CSI driver.

You can enable Longhorn and configure it as the default StorageClass for your cluster via module variables:

* **Enable Longhorn:**
  Set `longhorn_enabled` to `true` to deploy Longhorn in your cluster.

* **Default StorageClass:**
  Set `longhorn_default_storage_class` to `true` if you want Longhorn to be the default StorageClass.

**Example:**

```hcl
longhorn_enabled               = true
longhorn_default_storage_class = true
```

For more information about Longhorn, see the [Longhorn documentation](https://longhorn.io/docs/).

</details>


<!-- Talos Backup -->
<details>
<summary><b>Talos Backup</b></summary>

This module natively supports Hcloud Object Storage. Below is an example of how to configure backups with [MinIO Client](https://github.com/minio/mc?tab=readme-ov-file#homebrew) (`mc`) and Hcloud Object Storage. While it's possible to create the bucket through the [Hcloud Console](https://console.hetzner.cloud), this method does not allow for the configuration of automatic retention policies.

Create an alias for the endpoint using the following command:
```sh
mc alias set <alias> \
  https://<location>.your-objectstorage.com \
  <access-key> <secret-key> \
  --api "s3v4" \
  --path "off"
```

Create a bucket with automatic retention policies to protect your backups:
```sh
mc mb --with-lock --region <location> <alias>/<bucket>
mc retention set GOVERNANCE 14d --default <alias>/<bucket>
```

Configure your `kubernetes.tf` file:
```hcl
talos_backup_s3_hcloud_url = "https://<bucket>.<location>.your-objectstorage.com"
talos_backup_s3_access_key = "<access-key>"
talos_backup_s3_secret_key = "<secret-key>"

# Optional: AGE X25519 Public Key for encryption
talos_backup_age_x25519_public_key = "<age-public-key>"

# Optional: Change schedule (cron syntax)
talos_backup_schedule = "0 * * * *"
```

For users of other object storage providers, configure `kubernetes.tf` as follows:
```hcl
talos_backup_s3_region   = "<region>"
talos_backup_s3_endpoint = "<endpoint>"
talos_backup_s3_bucket   = "<bucket>"
talos_backup_s3_prefix   = "<prefix>"

# Use path-style URLs (set true if required by your provider)
talos_backup_s3_path_style = true

# Access credentials
talos_backup_s3_access_key = "<access-key>"
talos_backup_s3_secret_key = "<secret-key>"

# Optional: AGE X25519 Public Key for encryption
talos_backup_age_x25519_public_key = "<age-public-key>"

# Optional: Change schedule (cron syntax)
talos_backup_schedule = "0 * * * *"
```

To recover from a snapshot, please refer to the Talos Disaster Recovery section in the [Documentation](https://www.talos.dev/latest/advanced/disaster-recovery/#recovery).
</details>

<!-- Talos Bootstrap Manifests -->
<details>
<summary><b>Talos Bootstrap Manifests</b></summary>

### Toggle Component Deployment in Bootstrap Manifests

During the cluster provisioning phase, each component manifest is applied using Talos's bootstrap manifests feature. However, this also means that the manifests are **re-applied** every time `terraform apply` is run, as part of the [automated Kubernetes upgrade process](https://www.talos.dev/latest/kubernetes-guides/upgrading-kubernetes/#automated-kubernetes-upgrade) triggered by the module.

This behavior can cause issues if you want to use GitOps tools like **FluxCD** or **ArgoCD** to manage the lifecycle of these components. Since Talos manages the application lifecycle, any changes made by FluxCD or ArgoCD (e.g., annotations or labels) may be overwritten or removed during upgrades, leading to conflicts.

Before delegating lifecycle control to other tools, you must **first remove the corresponding manifests from the Talos machine configuration**. This can be done after the initial cluster provisioning using the following Terraform variables:

```hcl
# Core Component Configuration
cilium_enabled                     = true  # Enabled by default
talos_backup_s3_enabled            = true  # Enabled by default
talos_ccm_enabled                  = true  # Enabled by default
talos_coredns_enabled              = true  # Enabled by default
hcloud_ccm_enabled                 = true  # Enabled by default
hcloud_csi_enabled                 = true  # Enabled by default
cert_manager_enabled               = true  # Disabled by default
ingress_nginx_enabled              = true  # Disabled by default
longhorn_enabled                   = true  # Disabled by default
metrics_server_enabled             = true  # Enabled by default
prometheus_operator_crds_enabled   = true  # Enabled by default

# Talos etcd backup is automatically enabled when any of the following S3 settings are defined
talos_backup_s3_endpoint    = "https://..."
talos_backup_s3_hcloud_url  = "https://<bucket>.<location>.your-objectstorage.com"

# Cluster Autoscaler Configuration
# Automatically enabled when one or more node pools are defined
cluster_autoscaler_nodepools = [
  {
    name     = "autoscaler"
    type     = "cpx11"
    location = "fsn1"
    min      = 0
    max      = 6
    labels   = {
      "autoscaler-node" = "true"
    }
    taints   = [
      "autoscaler-node=true:NoExecute"
    ]
  }
]
```

> **Note:** Disabling a component **does not delete** its deployed resources. This is explicitly stated in the [Talos documentation](https://www.talos.dev/latest/kubernetes-guides/upgrading-kubernetes/#automated-kubernetes-upgrade).

After removing the component from the bootstrap manifests, you can either delete the existing resources manually before reapplying, or allow FluxCD/ArgoCD to take over their reconciliation and ongoing management.

### Adding Additional Manifests

In addition to the default components, you can also include extra bootstrap manifests using the variables below:

```hcl
# Extra remote manifests (fetched from the internet)
talos_extra_remote_manifests = [
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
]

# Extra inline manifests (defined directly in Terraform)
talos_extra_inline_manifests = [
  {
    name = "test-manifest"
    contents = <<-EOF
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: test-secret
      data:
        secret: dGVzdA==
    EOF
  }
]
```

</details>

<!-- Talos Discovery Service -->
<details>
<summary><b>Talos Discovery Service</b></summary>

Talos supports two node discovery mechanisms:

- **Discovery Service Registry** (default): A public, external registry operated by Sidero Labs that works even when Kubernetes is unavailable. Nodes must have outbound access to TCP port 443 to communicate with it.  
- **Kubernetes Registry**: Relies on Kubernetes Node metadata stored in etcd.

This module uses the discovery service to perform additional health checks during Talos upgrades, Kubernetes upgrades, and Kubernetes manifest synchronization. If no discovery mechanism is enabled, these additional checks will be skipped.

> :warning: **Important:** Kubernetes-based discovery is **incompatible by default** with Kubernetes **v1.32+** due to the `AuthorizeNodeWithSelectors` feature gate, which restricts access to Node metadata. This can cause broken discovery behavior, such as failing or incomplete results from `talosctl health` or `talosctl get members`.

##### Example Configuration

```hcl
# Disable Kubernetes-based discovery (deprecated in Kubernetes >= 1.32)
talos_kubernetes_discovery_service_enabled = false

# Enable the external Sidero Labs discovery service (default)
talos_siderolabs_discovery_service_enabled = true
```

For more details, refer to the [official Talos discovery guide](https://www.talos.dev/latest/talos-guides/discovery/).
</details>

<!-- Kubernetes RBAC -->
<details>
<summary><b>Kubernetes RBAC</b></summary>

This module allows you to create custom Kubernetes RBAC (Role-Based Access Control) roles and cluster roles that define specific permissions for users and groups. RBAC controls what actions users can perform on which Kubernetes resources.  
These custom roles can be used independently or combined with OIDC group mappings to automatically assign permissions based on user group membership from your identity provider.

#### Example Configuration

##### Cluster Roles (`rbac_cluster_roles`)

```hcl
rbac_cluster_roles = [
  {
    name  = my-cluster-role                    # ClusterRole name
    rules = [
      {
        api_groups = [""]                      # Core API group (empty string for core resources)
        resources  = ["nodes"]                 # Cluster-wide resources this role can access
        verbs      = ["get", "list", "watch"]  # Actions allowed on these resources
      }
    ]
  }
]
```

##### Namespaced Roles (`rbac_roles`)

```hcl
rbac_roles = [
  {
    name      = "my-role"                      # Role name
    namespace = "target-namespace"             # Namespace where the role will be created
    rules = [
      {
        api_groups = [""]                      # Core API group (empty string for core resources)
        resources  = ["pods", "services"]      # Resources this role can access
        verbs      = ["get", "list", "watch"]  # Actions allowed on these resources
      }
    ]
  }
]
```

</details>

<!-- OIDC Cluster Authentication -->
<details>
<summary><b>OIDC Cluster Authentication</b></summary>

The Kubernetes API server supports OIDC (OpenID Connect) authentication, allowing integration with external identity providers like Keycloak, Auth0, Authentik, Zitadel, etc.
When enabled, users can authenticate using their existing organizational credentials instead of managing separate Kubernetes certificates or tokens.

OIDC authentication works by validating JWT tokens issued by your identity provider, extracting user information and group memberships, and mapping them to Kubernetes RBAC roles.

#### Example Configuration

```hcl
# OIDC Configuration
oidc_enabled        = true                               # Enable OIDC authentication
oidc_issuer_url     = "https://your-oidc-provider.com"   # Your OIDC provider issuer URL
oidc_client_id      = "your-client-id"                   # Client ID registered in your OIDC provider
oidc_username_claim = "preferred_username"               # OIDC JWT claim to extract username from
oidc_groups_claim   = "groups"                           # OIDC JWT claim to extract user groups from
oidc_groups_prefix  = "oidc:"                            # Prefix added to group names in K8s to avoid conflicts

# Map OIDC groups to Kubernetes roles and cluster roles
oidc_group_mappings = [                                  # List of OIDC group mappings
  {
    group         = "cluster-admins-group"               # OIDC provider group name
    cluster_roles = ["cluster-admin"]                    # Grant cluster-admin access
  },
  {
    group         = "developers-group"                   # OIDC provider group name
    cluster_roles = ["view"]                             # Grant cluster-wide view access
    roles = [                                            # Grant namespace scoped roles
      {
        name      = "developer-role"                     # Custom role name
        namespace = "development"                        # Namespace where role applies
      }
    ]
  }
]
```

#### Client Configuration with kubelogin

Once OIDC is configured in your cluster, you'll need to configure your local kubectl to authenticate using OIDC tokens. This requires the [kubelogin](https://github.com/int128/kubelogin) plugin.

##### Install kubelogin

```bash
# Homebrew (macOS and Linux)
brew install kubelogin

# Krew (macOS, Linux, Windows and ARM)
kubectl krew install oidc-login

# Chocolatey (Windows)
choco install kubelogin
```

#### Test OIDC Authentication

First, verify that your OIDC provider is returning proper JWT tokens. Replace the placeholder values with your actual OIDC configuration:

```bash
kubectl oidc-login setup \
  --oidc-issuer-url=https://your-oidc-provider.com \
  --oidc-client-id=your-client-id \
  --oidc-client-secret=your-client-secret \           
  --oidc-extra-scope=openid,email,profile             # Add or change the scopes according to your IDP
```

This will open your browser for authentication. After successful login, you should see a JWT token in your terminal that looks like:

```json
{
  "aud": "your-client-id",
  "email": "user@example.com",
  "email_verified": true,
  "exp": 1749867571,
  "groups": [
    "developers",
    "kubernetes-users"
  ],
  "iat": 1749863971,
  "iss": "https://your-oidc-provider.com",
  "nonce": "random-nonce-string",
  "sub": "user-unique-identifier"
}
```

Verify that:

- The `groups` array contains your expected groups
- The `email` field matches your user email
- `email_verified` is `true` (required by K8s)

#### Configure kubectl

Add a new user to your `~/.kube/config` file:

```yaml
users:
- name: oidc-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: kubectl
      args:
        - oidc-login
        - get-token
        - --oidc-issuer-url=https://your-oidc-provider.com
        - --oidc-client-id=your-client-id
        - --oidc-client-secret=your-client-secret
        - --oidc-extra-scope=groups
        - --oidc-extra-scope=email
        - --oidc-extra-scope=name                           # Add or change the scopes according to your IDP
```

Update your context to use the new OIDC user:

```yaml
contexts:
- context:
    cluster: your-cluster
    namespace: default
    user: oidc-user          # Changed from certificate-based user
  name: oidc@your-cluster    # Updated context name
```

Now you can switch to the OIDC context and authenticate using your identity provider:

```bash
kubectl config use-context your-cluster-oidc
kubectl get pods  # This will trigger OIDC authentication
```

</details>

<!-- Lifecycle -->
## :recycle: Lifecycle
The [Talos Terraform Provider](https://registry.terraform.io/providers/siderolabs/talos) does not support declarative upgrades of Talos or Kubernetes versions. This module compensates for these limitations using `talosctl` to implement the required functionalities. Any minor or major upgrades to Talos and Kubernetes will result in a major version change of this module. Please be aware that downgrades are typically neither supported nor tested.

> [!IMPORTANT]
> Before upgrading to the next major version of this module, ensure you are on the latest release of the current major version. Do not skip any major release upgrades.

### :white_check_mark: Version Compatibility Matrix
| Hcloud K8s |  K8s  | Talos | Talos CCM | Hcloud CCM | Hcloud CSI | Long-horn | Cilium | Ingress NGINX | Cert Mgr. | Auto-scaler |
| :--------: | :---: | :---: | :-------: | :--------: | :--------: | :-------: | :----: | :-----------: | :-------: | :---------: |
|  **(3)**   | 1.33  | 1.10  |   1.10    |    1.26    |    2.14    |   1.8.2   |  1.18  |     4.13      |   1.18    |    9.47     |
|   **2**    | 1.32  |  1.9  |    1.9    |    1.23    |    2.12    |   1.8.1   |  1.17  |     4.12      |   1.17    |    9.45     |
|   **1**    | 1.31  |  1.8  |    1.8    |    1.21    |    2.10    |    1.8    |  1.17  |     4.12      |   1.15    |    9.38     |
<!--
|   **0**    | 1.30  |  1.7  |    1.6    |    1.20    |    2.9     |   1.7.1   |  1.16  |    4.10.1     |   1.14    |    9.37     |
-->

In this module, upgrades are conducted with care. You will consistently receive the most tested and compatible releases of all components, avoiding the latest untested or incompatible releases that could disrupt your cluster.

> [!WARNING]
> Do not change any software versions in this project on your own. Each component is tailored to ensure compatibility with new Kubernetes releases. This project specifies versions that are supported and have been thoroughly tested to work together.

<!--
- Talos/K8s: https://github.com/siderolabs/talos/blob/release-1.6/pkg/machinery/constants/constants.go
- HCCM: https://github.com/hetznercloud/hcloud-cloud-controller-manager/tree/main?tab=readme-ov-file#versioning-policy
- HCSI: https://github.com/hetznercloud/csi-driver/blob/main/docs/kubernetes/README.md#versioning-policy
- Longhorn: https://longhorn.io/docs/1.7.2/best-practices/#kubernetes-version
- Cilium: https://github.com/cilium/cilium/blob/v1.15/Documentation/network/kubernetes/requirements.rst#kubernetes-version
- Ingress Nginx: https://github.com/kubernetes/ingress-nginx?tab=readme-ov-file#supported-versions-table 
- Cert Manager: https://cert-manager.io/docs/releases/
- Autoscaler: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/README.md#releases
-->


<!-- Roadmap -->
## :compass: Roadmap
* [ ] **Upgrade to Talos 1.10 and Kubernetes 1.33**<br>
      Once all components have compatible versions, the upgrade can be performed.
* [x] **Upgrade to Talos 1.9 and Kubernetes 1.32**<br>
      Once all components have compatible versions, the upgrade can be performed.

<!-- Contributing -->
## :wave: Contributing

<a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=hcloud-k8s/terraform-hcloud-kubernetes" />
</a>


Contributions are always welcome!

<!-- License -->
## :balance_scale: License

Distributed under the MIT License. See [LICENSE](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/LICENSE) for more information.

<!-- Acknowledgments -->
## :gem: Acknowledgements

- [Talos Linux](https://www.talos.dev) for its impressively secure, immutable, and minimalistic Kubernetes distribution.
- [Hetzner Cloud](https://www.hetzner.com/cloud) for offering excellent cloud infrastructure with robust Kubernetes integrations.
- Other projects like [Kube-Hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) and [Terraform - Hcloud - Talos](https://github.com/hcloud-talos/terraform-hcloud-talos), where we’ve contributed and gained valuable insights into Kubernetes deployments on Hetzner.
