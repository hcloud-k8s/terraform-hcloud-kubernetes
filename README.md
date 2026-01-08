<div align="center">

  <img src="https://avatars.githubusercontent.com/u/182015181" alt="logo" width="225" height="auto" />
  <h1>Hcloud Kubernetes</h1>

  <p>
    Terraform Module to deploy Kubernetes on Hetzner Cloud! 
  </p>

<!-- Badges -->
<p>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/latest">
    <img src="https://img.shields.io/github/release/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="last update" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/commit/main">
    <img src="https://img.shields.io/github/last-commit/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="last update" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/stargazers">
    <img src="https://img.shields.io/github/stars/hcloud-k8s/terraform-hcloud-kubernetes" alt="stars" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/network/members">
    <img src="https://img.shields.io/github/forks/hcloud-k8s/terraform-hcloud-kubernetes" alt="forks" />
  </a>
  <a href="https://search.opentofu.org/module/hcloud-k8s/kubernetes/hcloud">
    <img src="https://img.shields.io/badge/OpenTofu-Hcloud--K8s-blue?logo=opentofu" alt="OpenTofu Module" />
  </a>
  <a href="https://registry.terraform.io/modules/hcloud-k8s/kubernetes/hcloud">
    <img src="https://img.shields.io/terraform/module/dt/hcloud-k8s/kubernetes/hcloud?logo=terraform&label=Terraform" alt="Terraform Registry downloads" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/search?l=hcl">
    <img src="https://img.shields.io/github/languages/top/hcloud-k8s/terraform-hcloud-kubernetes?logo=hashicorp&label=HCL" alt="HCL top language" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/issues/">
    <img src="https://img.shields.io/github/issues/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="open issues" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/pulls">
    <img src="https://img.shields.io/github/issues-pr/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="open pull requests" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/discussions">
    <img src="https://img.shields.io/github/discussions/hcloud-k8s/terraform-hcloud-kubernetes?logo=github&label=discussions" alt="discussions" />
  </a>
  <a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/hcloud-k8s/terraform-hcloud-kubernetes?logo=github" alt="license" />
  </a>
</p>

</div>

<br />

<!-- Table of Contents -->
# 📔 Overview
- [🌟 About the Project](#-about-the-project)
- [🚀 Getting Started](#-getting-started)
- [⚙️ Advanced Configuration](#%EF%B8%8F-advanced-configuration)
- [♻️ Lifecycle](#%EF%B8%8F-lifecycle)
- [❤️ Support this Project](#%EF%B8%8F-support-this-project)
- [👋 Community](#-community)
- [📎 Project Info](#-project-info)

<!-- About the Project -->
## 🌟 About the Project
Hcloud Kubernetes is a Terraform module for deploying a fully declarative, managed Kubernetes cluster on Hetzner Cloud. It utilizes Talos, a secure, immutable, and minimal operating system specifically designed for Kubernetes, featuring a streamlined architecture with only a handful of binaries and shared libraries. Just enough to run containerd and a small set of system services.

This project is committed to production-grade configuration and lifecycle management, ensuring all components are set up for high availability. It includes a curated selection of widely used and officially recognized Kubernetes components. If you encounter any issues, suboptimal settings, or missing elements, please file an [issue](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/issues) to help us improve this project.

> [!TIP]
> If you don’t have a Hetzner account yet, you can use this [Hetzner Cloud Referral Link](https://hetzner.cloud/?ref=GMylKeDmqtsD) to claim a €20 credit and support this project at the same time.

<!-- Features -->
### ✨ Features

Provision a highly available and secure Kubernetes cluster on Hetzner Cloud, defined by these key features:

* **Immutable Infrastructure:** Utilizes Talos Linux to provide a fully declarative, completely immutable Kubernetes cluster.
* **Architecture Flexibility:** Supports deployment on both **AMD64** and **ARM64** instances with automated image synchronization.
* **Maximized Uptime:** Delivers high availability across all control plane and worker components for consistent, reliable performance.
* **Elastic Scaling:** Supports automatic scaling of both **nodes** and **pods** to effortlessly accommodate dynamic workloads.
* **Quick Start Addons:** Optional, pre-integrated Ingress Controller and Cert Manager simplifies the rapid deployment of applications.
* **Dual-Stack Networking:** Load Balancers offer native support for both **IPv4** and **IPv6** for modern, efficient traffic management.
* **Isolated Network Fabric:** Ensures all internal cluster traffic is confined to an isolated, private Hetzner Cloud Network.
* **Comprehensive Security:** Enforces a security-first design with perimeter firewalls and encryption applied to data both in transit and at rest.

<!-- Components -->
### 📦 Components
This project bundles essential Kubernetes components, preconfigured for seamless operation on Hetzner Cloud:
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
  Provides persistent storage for Kubernetes using Hetzner Cloud Volumes, supporting encryption and dynamic provisioning.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=longhorn.io&sz=32" width="16" height="16">
    <b><a href="https://longhorn.io">Longhorn</a></b>
  </summary>
  Distributed block storage for Kubernetes, providing high availability, snapshots, and automatic replica rebuilding for easy persistent volume management.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=cilium.io&sz=32" width="16" height="16">
    <b><a href="https://cilium.io">Cilium Container Network Interface (CNI)</a></b>
  </summary>
  A high performance CNI plugin that enhances and secures network connectivity and observability for container workloads through the use of eBPF technology in Linux kernels.
- <summary>
    <img align="center" alt="Easy" src="https://www.google.com/s2/favicons?domain=cilium.io&sz=32" width="16" height="16">
    <b><a href="https://cilium.io/use-cases/gateway-api/">Cilium Gateway API</a></b>
  </summary>
  Cilium Gateway API implements the Kubernetes Gateway API using eBPF for traffic steering and policy enforcement, with Envoy providing Layer 7 proxying for HTTP and TLS routing.
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
### 🛡️ Security
Talos Linux is a secure, minimal, and immutable OS for Kubernetes, removing SSH and shell access to reduce attack surfaces. Managed through a secure API with mTLS, Talos prevents configuration drift, enhancing both security and predictability. It follows [NIST](https://www.nist.gov/publications/application-container-security-guide) and [CIS](https://www.cisecurity.org/benchmark/kubernetes) hardening standards, operates in memory, and is built to support modern, production-grade Kubernetes environments.

**Perimeter Security:** External access to cluster nodes is controlled and restricted using [Hetzner Cloud Firewall](https://docs.hetzner.com/cloud/firewalls/).

**Network Policy:** Internal cluster traffic can be governed by Kubernetes Network Policies using [Cilium CNI](https://docs.cilium.io/en/stable/network/kubernetes/policy/).

**Encryption in Transit:** Pod network traffic is transparently encrypted by Cilium using [WireGuard](https://docs.cilium.io/en/latest/security/network/encryption-wireguard/) by default, with optional support for [IPsec](https://docs.cilium.io/en/latest/security/network/encryption-ipsec/).

**Encryption at Rest:** The [STATE](https://www.talos.dev/latest/learn-more/architecture/#file-system-partitions) and [EPHEMERAL](https://www.talos.dev/latest/learn-more/architecture/#file-system-partitions) partitions are encrypted by default using [Talos Disk Encryption](https://www.talos.dev/latest/talos-guides/configuration/disk-encryption/) with LUKS2. Each node is secured with an individual encryption key derived from its unique `nodeID`.

<!-- Getting Started -->
## 🚀 Getting Started

<!-- Prerequisites -->
### ✅ Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/install) or [tofu](https://opentofu.org/docs/intro/install/) to deploy the Cluster
- [packer](https://developer.hashicorp.com/packer/install) to upload Talos Images
- [jq](https://jqlang.org/download/) for internal API Communication
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl) to control the Talos Cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) to control Kubernetes (optional)

> [!IMPORTANT]
> Keep the CLI tools up to date. Ensure that `talosctl` matches your Talos version for compatibility, especially before a Talos upgrade.

<!-- Installation -->
### 🎯 Installation

Create `kubernetes.tf` file with the module configuration:
```hcl
module "kubernetes" {
  source  = "hcloud-k8s/kubernetes/hcloud"
  version = "<version>"

  cluster_name = "k8s"
  hcloud_token = "<hcloud-token>"

  # Export configs for talosctl and kubectl (optional)
  cluster_kubeconfig_path  = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  # Enable Cilium Gateway API and Cert Manager (optional)
  cert_manager_enabled       = true
  cilium_gateway_api_enabled = true

  control_plane_nodepools = [
    { name = "control", type = "cpx22", location = "nbg1", count = 3 }
  ]
  worker_nodepools = [
    { name = "worker", type = "cpx22", location = "nbg1", count = 3 }
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
### 🔑 Cluster Access

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

### 💥 Teardown
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
## ⚙️ Advanced Configuration

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
network_native_routing_ipv4_cidr = "10.0.0.0/8"

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
1. **Use single Control Plane IP (default):**<br>
    By default the IP address of a single Control Plane node is used to access the Kube API.
2. **Use a Load Balancer:**<br>
    Deploy a load balancer to manage API traffic, enhancing availability and load distribution.
    ```hcl
    kube_api_load_balancer_enabled = true
    ```
3. **Use a Virtual IP (Floating IP):**<br>
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
    type     = "cpx22"
    location = "nbg1"
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

##### Talos Upgrades and Configuration Changes
Cluster Autoscaler does not support upgrading nodes or changing their configuration, as its primary purpose is to manage short-lived nodes that handle load peaks. If you require long-lived autoscaled nodes, you can upgrade them manually using `talosctl` or use this Terraform module, which supports discovery of autoscaled nodes and manages their upgrades and configuration changes.

To enable this feature, add the following to your configuration:
```hcl
cluster_autoscaler_discovery_enabled = true
```

Please note that errors may occur if a node pool has been scaled down recently, as Talos caches absent nodes for up to [30 minutes](https://www.talos.dev/latest/introduction/troubleshooting/#removed-members-are-still-present). You can pause automatic scaling by stopping the Cluster Autoscaler pods:
```sh
kubectl -n kube-system scale deployment cluster-autoscaler-hetzner-cluster-autoscaler --replicas=0
```

</details>


<!-- Cilium Advanced Configuration -->
<details>
<summary><b>Cilium Advanced Configuration</b></summary>

#### Cilium CIDR Policy Match Mode

By default, when using K8s NetworkPolicies CIDR-based selectors in Cilium do not match in-cluster entities (pods or nodes). This is however required when using NetworkPolicies that control traffic to the kube-apiserver pods as these use the Talos node IPs in our setup.
Cilium's policy engine can be directed to select nodes by CIDR / ipBlock. This requires you to add the following to your configuration:

```hcl
cilium_policy_cidr_match_mode = "nodes"
```

It is safe to toggle this option on a running cluster, and toggling the option affects neither upgrades nor downgrades
More information can be found in [the Cilium docs.](https://docs.cilium.io/en/stable/security/policy/language/#selecting-nodes-with-cidr-ipblock)

#### Cilium Transparent Encryption

This module enables [Cilium Transparent Encryption](https://cilium.io/use-cases/transparent-encryption/) feature by default.  

All pod network traffic is encrypted using WireGuard (Default) or  protocols, includes automatic key rotation and efficient in-kernel encryption, covering all traffic types.

💡 Although WireGuard is the default option, Hetzner Cloud VMs supports AES-NI instruction set, making IPSec encryption more CPU-efficient compared to WireGuard. Consider enabling IPSec for CPU savings through hardware acceleration.

IPSec mode supports RFC4106 AES-GCM encryption with 128, 192 and 256 bits key sizes.


**⚠️ IPSec encryption has the following limitations:**

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
    type     = "cpx22"
    location = "nbg1"
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

<!-- Gateway API -->
<details>
<summary><b>Gateway API</b></summary>

Kubernetes Gateway API is the modern replacement for Kubernetes Ingress. It fixes many Ingress limitations by offering a richer, more consistent model for traffic management, and it's designed to support multiple [Gateway API implementations](https://gateway-api.sigs.k8s.io/implementations/#conformant) in parallel.

This module installs the Gateway API CRDs by default and deploys Cert Manager with Gateway API support enabled.

### Example with Cilium Gateway API and Cert Manager TLS Certificate

To use Cilium's Gateway API implementation, configure:
```hcl
cilium_gateway_api_enabled = true
```

If Cert Manager and Cilium weren't initially deployed/configured with Gateway API support enabled, you may need to restart their controllers to pick up the new configuration:
```shell
kubectl -n cert-manager rollout restart deployment
kubectl -n kube-system rollout restart deployment/cilium-operator
```

#### Create a Cert Manager `Issuer` (Let's Encrypt HTTP-01 via Gateway API)

`Issuer` configures Cert Manager to request TLS certificates from Let's Encrypt using the ACME `HTTP-01` challenge. The important part is the `gatewayHTTPRoute` solver: when Cert Manager needs to prove domain ownership, it will temporarily create/attach an HTTPRoute under the referenced `Gateway` and serve the `/.well-known/acme-challenge/...` response there.

Replace the placeholder email address, and note that `privateKeySecretRef` is the secret where Cert Manager stores your ACME account key (not the issued certificate).

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-http01
  namespace: default
spec:
  acme:
    email: <user@example.com>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-http01-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: cilium-gateway
                namespace: default
                kind: Gateway
```

#### Create the `Gateway` (Cilium GatewayClass + Hetzner LB + Cert Manager integration)

A `Gateway` defines the external entry point for traffic. With `gatewayClassName: cilium`, the resource is reconciled by the Cilium Gateway controller. The `infrastructure.annotations` are passed through as Hetzner-specific load balancer settings (interpreted by the Hetzner Cloud Controller Manager) to control how the Hetzner Cloud LB is created and configured. See: [Load Balancer Annotations](https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/docs/reference/load_balancer_annotations.md)

The `cert-manager.io/issuer: letsencrypt-http01` annotation is used by Cert Manager's Gateway shim so it knows which Issuer to use when populating the TLS secret referenced by the listener.

`tls.certificateRefs` points at the Kubernetes Secret that will contain the issued certificate and private key (`example-com-tls`). Cert Manager will keep that secret up to date, and the Gateway will use it to terminate TLS.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: cilium-gateway
  namespace: default
  annotations:
    cert-manager.io/issuer: letsencrypt-http01
spec:
  gatewayClassName: cilium
  infrastructure:
    annotations:
      load-balancer.hetzner.cloud/name: "cilium-gateway-nbg1"
      load-balancer.hetzner.cloud/location: "nbg1"
      load-balancer.hetzner.cloud/uses-proxyprotocol: "true"
  listeners:
    - name: https
      hostname: example.com
      port: 443
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: example-com-tls
            kind: Secret
            group: ""
    - name: http
      hostname: example.com
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: All
```

#### Create an `HTTPRoute` (bind hostname + route traffic to your service)

Finally, the `HTTPRoute` attaches to the Gateway and defines routing rules for `example.com`. In this example it forwards all matching requests to a Kubernetes Service called `example-service` on port `8080`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-app
  namespace: default
spec:
  hostnames:
    - example.com
  parentRefs:
    - name: cilium-gateway
      namespace: default
  rules:
    - backendRefs:
        - name: example-service
          port: 8080
```

> ⚠️ **Important:** When using PROXY protocol with Cilium Gateway API (enabled by default), external IPv6 connections will not work due to a bug in Cilium’s Gateway API implementation: [https://github.com/cilium/cilium/issues/42950](https://github.com/cilium/cilium/issues/42950)
> 
> If you need IPv6, disable PROXY protocol by adding the `load-balancer.hetzner.cloud/uses-proxyprotocol: "false"` infrastructure annotation and setting this module config:
> ```
> cilium_gateway_api_proxy_protocol_enabled = false
> ```
> After applying the module config, you may need to restart Cilium to pick up the change:
> ```shell
> kubectl -n kube-system rollout restart deployment/cilium-operator
> ```

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

### Component Deployment Control

During cluster provisioning, each component manifest is applied using Talos’s bootstrap manifests feature. Components are upgraded as part of the normal lifecycle of this module.
You can enable or disable component deployment using the variables below:

```hcl
# Core Components (enabled by default)
cilium_enabled                     = true
talos_backup_s3_enabled            = true
talos_ccm_enabled                  = true
talos_coredns_enabled              = true
hcloud_ccm_enabled                 = true
hcloud_csi_enabled                 = true
metrics_server_enabled             = true
prometheus_operator_crds_enabled   = true

# Additional Components (disabled by default)
cert_manager_enabled               = true
ingress_nginx_enabled              = true
longhorn_enabled                   = true

# Enable etcd backup by defining one of these variables:
talos_backup_s3_endpoint    = "https://..."
talos_backup_s3_hcloud_url  = "https://<bucket>.<location>.your-objectstorage.com"

# Cluster Autoscaler: Enabled when node pools are defined
cluster_autoscaler_nodepools = [
  {
    name     = "autoscaler"
    type     = "cpx22"
    location = "nbg1"
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

> **Note:** Disabling a component **does not delete** its existing resources.
> This is documented in the [Talos documentation](https://www.talos.dev/latest/kubernetes-guides/upgrading-kubernetes/#automated-kubernetes-upgrade).
> You must remove deployed resources manually after disabling a component in the manifests.

---

### Adding Additional Manifests

Besides the default components, you can add extra bootstrap manifests as follows:

```hcl
# Extra remote manifests (URLs fetched at apply time)
talos_extra_remote_manifests = [
  "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml"
]

# Extra inline manifests (defined directly)
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

> ⚠️ **Important:** Kubernetes-based discovery is **incompatible by default** with Kubernetes **v1.32+** due to the `AuthorizeNodeWithSelectors` feature gate, which restricts access to Node metadata. This can cause broken discovery behavior, such as failing or incomplete results from `talosctl health` or `talosctl get members`.

##### Example Configuration

```hcl
# Disable Kubernetes-based discovery (deprecated in Kubernetes >= 1.32)
talos_kubernetes_discovery_service_enabled = false

# Enable the external Sidero Labs discovery service (default)
talos_siderolabs_discovery_service_enabled = true
```

For more details, refer to the [official Talos discovery guide](https://www.talos.dev/latest/talos-guides/discovery/).
</details>

<!-- Talos OOM Handler -->
<details>
<summary><b>Talos OOM Handler Configuration</b></summary>

Talos 1.12+ includes a userspace Out-of-Memory (OOM) handler that is always enabled by default with built-in configuration. This handler provides early detection of memory pressure and helps prevent machine lock-up due to out-of-memory conditions, which is especially important for single-node clusters or when scheduling pods on control plane nodes.

While the Linux kernel's OOM killer only activates when completely out of memory (at which point the system may be unresponsive), the Talos userspace OOM handler proactively monitors memory pressure and can take action earlier to maintain system stability.

#### Default Behavior

The OOM handler uses [Pressure Stall Information (PSI)](https://docs.kernel.org/accounting/psi.html) metrics to detect memory pressure and Common Expression Language (CEL) expressions to determine when and what to kill:

- **Trigger**: Activates when full memory pressure (10s average) exceeds 12% AND is increasing AND at least 500ms have passed since the last OOM event
- **Ranking**: Prioritizes killing pods without memory limits first, specifically BestEffort pods (highest priority), then Burstable pods, while protecting Guaranteed pods and system services

#### Customization

This module allows you to customize the OOM handler behavior if the defaults don't suit your workload requirements:

```hcl
# Custom OOM configuration enabled
talos_custom_oom_enabled                    = true

# Custom trigger - this expression defines when to trigger OOM action.
talos_custom_oom_trigger_expression         = "memory_full_avg10 > 12.0 && d_memory_full_avg10 > 0.0 && time_since_trigger > duration(\"500ms\")"

# Custom ranking - this expression defines how to rank cgroups for OOM handler.
talos_custom_oom_cgroup_ranking_expression  = "memory_max.hasValue() ? 0.0 : {Besteffort: 1.0, Burstable: 0.5, Guaranteed: 0.0, Podruntime: 0.0, System: 0.0}[class] * double(memory_current.orValue(0u))"

# Custom sample interval - how often should the trigger expression be evaluated.
talos_custom_oom_sample_interval            = "100ms"
```

You can override any combination of these settings. The module validates that at least one custom field is provided when `talos_custom_oom_enabled = true`.

For more details, refer to the [Talos OOM Handler documentation](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/system-configuration/oom) and [OOMConfig reference](https://docs.siderolabs.com/talos/v1.12/reference/configuration/runtime/oomconfig).
</details>

<!-- Talos Directory Volumes -->
<details>
<summary><b>Talos Directory Volumes</b></summary>

Talos 1.12+ supports creating using directories on the EPHEMERAL partition as storage volumes. These volumes are automatically mounted at `/var/mnt/<name>` and provide persistent storage across pod restarts without requiring additional block devices or partitions.

This feature is particularly useful for workloads that need host directories, such as:

- **Local Path Provisioner**: Kubernetes dynamic volume provisioner using local storage
- **Shared cache directories**: Persistent cache storage for applications
- **Build artifacts**: CI/CD pipelines requiring shared build output
- **Logging/metrics collection**: Centralized log or metric storage from workloads

#### Configuration

Directory volumes can be configured separately for each node type (control plane, workers, autoscaler):

```hcl
# Control plane directory volumes
control_plane_directory_volumes = ["local-storage", "cache-data"]

# Worker directory volumes
worker_directory_volumes = ["local-storage", "build-cache"]

# Cluster autoscaler directory volumes (optional)
cluster_autoscaler_directory_volumes = ["temp-storage"]
```

#### Example: Local Path Provisioner

Deploy the Kubernetes Local Path Provisioner to use directory volumes for dynamic PV provisioning:

```hcl
# Define directory volumes for worker nodes
worker_directory_volumes = ["local-storage"]
```

The directory `/var/mnt/local-storage` will be created on all worker nodes and can be used by the Local Path Provisioner for dynamic volume provisioning.

#### Important Considerations

**Data Persistence:**

- ⚠️ **Data loss on node failure**: If a node fails or is replaced, all data in directory volumes on that node is permanently lost
- ⚠️ **Ephemeral partition wipe**: Recreating or resetting a node wipes the EPHEMERAL partition, destroying all directory volume data
- For critical data requiring high availability, use Hetzner Cloud Volumes (via Hcloud CSI) or Longhorn distributed storage instead
- Directory volumes inherit encryption from the EPHEMERAL partition

**Storage Limitations:**

- **Shared capacity**: All directory volumes share the EPHEMERAL partition's total capacity
- **No quotas**: Cannot enforce per-directory storage limits
- **No filesystem isolation**: Directory-type volumes don't provide filesystem-level isolation

For more details, refer to the [Talos UserVolumeConfig documentation](https://docs.siderolabs.com/talos/v1.12/reference/configuration/runtime/uservolumeconfig).
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
## ♻️ Lifecycle
Any minor or major upgrades to Talos and Kubernetes will result in a major version change of this module. Please be aware that downgrades are typically neither supported nor tested.

> [!IMPORTANT]
> Before upgrading to the next major version of this module, ensure you are on the latest release of the current major version. Do not skip any major release upgrades.

### ☑️ Version Compatibility Matrix
The table below lists the minimum required versions of each component to support the specified Kubernetes release.

| Hcloud K8s | Kubernetes | Hcloud CCM | Hcloud CSI | Longhorn | Cilium | Ingress NGINX | Cert Manager |
| :--------: | :--------: | :--------: | :--------: | :------: | :----: | :-----------: | :----------: |
|  **(5)**   |    1.34    |    1.27    |    2.18    |    ?     | (1.19) |     4.14      |     1.19     |
|  **(4)**   |    1.33    |    1.26    |    2.14    |  1.8.2   |  1.18  |     4.13      |     1.18     |
<!--
|   **3**    |    1.33    |    1.26    |    2.14    |   1.8.2  |  1.18  |     4.13      |     1.18     |
|   **2**    |    1.32    |    1.23    |    2.12    |   1.8.1  |  1.17  |     4.12      |     1.17     |
|   **1**    |    1.31    |    1.21    |    2.10    |    1.8   |  1.17  |     4.12      |     1.15     |
|   **0**    |    1.30    |    1.20    |    2.9     |   1.7.1  |  1.16  |    4.10.1     |     1.14     |
-->

In this module, upgrades are conducted with care. You will consistently receive the most tested and compatible releases of all components.

> [!WARNING]
> It is not recommended to change any software versions in this project on your own. Each component is specifically configured for compatibility with new Kubernetes releases. The specified versions are supported and have been tested to work together.

<!--
- Talos/K8s: https://github.com/siderolabs/talos/blob/release-1.6/pkg/machinery/constants/constants.go
- HCCM: https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/becfd60814cd868ca972492298f17b8e7e11c8ed/docs/reference/version-policy.md
- HCSI: https://github.com/hetznercloud/csi-driver/blob/main/docs/kubernetes/README.md#versioning-policy
- Longhorn: https://longhorn.io/docs/1.10.0/best-practices/#kubernetes-version
- Cilium: https://github.com/cilium/cilium/blob/v1.15/Documentation/network/kubernetes/requirements.rst#kubernetes-version
- Ingress Nginx: https://github.com/kubernetes/ingress-nginx?tab=readme-ov-file#supported-versions-table 
- Cert Manager: https://cert-manager.io/docs/releases/
- Autoscaler: https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/README.md#releases
-->


<!-- Roadmap -->
### 🧭 Roadmap
* [ ] **Ingress NGINX [Retirement in March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)**<br>
  * [x] Add general support for Gateway API
  * [x] Integrate Cilium Gateway API
  * [ ] Deprecate Ingress NGINX in v4 (~ Q1 2026)
  * [ ] Remove Ingress NGINX in v5 (~ Q2/Q3 2026)
* [ ] **Upgrade to latest Talos 1.12**<br>
      Once all components have compatible versions, the upgrade can be performed.


<!-- Support this Project -->
## ❤️ Support this Project
If you'd like to support this project, please consider leaving a ⭐ on GitHub!<br>
<a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes">
  <img
    src="https://img.shields.io/github/stars/hcloud-k8s/terraform-hcloud-kubernetes"
    alt="Stars"
    width="105"
  />
</a>


<picture>
 <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=hcloud-k8s/terraform-hcloud-kubernetes&type=date&theme=dark&legend=top-left" />
 <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=hcloud-k8s/terraform-hcloud-kubernetes&type=date&legend=top-left" />
 <img width="700" alt="Star History Chart" src="https://api.star-history.com/svg?repos=hcloud-k8s/terraform-hcloud-kubernetes&type=date&legend=top-left" />
</picture>

> [!TIP]
> If you don’t have a Hetzner account yet, you can use this [Hetzner Cloud Referral Link](https://hetzner.cloud/?ref=GMylKeDmqtsD) to claim a €20 credit and support this project at the same time.

### 💖 Special Thanks to All Sponsors! 💖
<!-- sponsors --><a href="https://github.com/jonakoudijs"><img src="https:&#x2F;&#x2F;github.com&#x2F;jonakoudijs.png" width="80px" alt="User avatar: jonakoudijs" /></a>&nbsp;&nbsp;<!-- sponsors -->

Your sponsorship supports the ongoing development, improvement, and maintenance of this project 🙏
<br>

**Become a Sponsor:**
- [![GitHub Sponsors](https://img.shields.io/github/sponsors/hcloud-k8s?label=GitHub%20Sponsors&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/hcloud-k8s)
- [![Liberapay](https://img.shields.io/liberapay/patrons/hcloud-k8s.svg?label=Liberapay%20Patrons&logo=liberapay)](https://liberapay.com/hcloud-k8s/donate)

<!-- Community -->
## 👋 Community
We welcome everyone to join the [Discussions](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/discussions), report [Issues](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/issues/new/choose), and help improve this project.

<!-- Contributing -->
### 🤝 Contributing

<a href="https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=hcloud-k8s/terraform-hcloud-kubernetes" />
</a>


Contributions are always welcome!

<!-- Project Meta -->
## 📎 Project Info
This project is built for the public and will always remain fully [Open Source](https://opensource.org/osd).

<!-- License -->
### ⚖️ License

Distributed under the MIT License. See [LICENSE](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/blob/main/LICENSE) for more information.

<!-- Acknowledgments -->
### 💎 Acknowledgements

- [Talos Linux](https://www.talos.dev) for its impressively secure, immutable, and minimalistic Kubernetes distribution.
- [Hetzner Cloud](https://www.hetzner.com/cloud) for offering excellent cloud infrastructure with robust Kubernetes integrations.
- [Kube-Hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) and [Terraform - Hcloud - Talos](https://github.com/hcloud-talos/terraform-hcloud-talos) for providing practical examples and inspiration for this module.
