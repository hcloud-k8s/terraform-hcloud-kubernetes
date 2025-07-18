# Hcloud Secret
locals {
  hcloud_secret_manifest = {
    name = "hcloud-secret"
    contents = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      type       = "Opaque"
      metadata = {
        name      = "hcloud"
        namespace = "kube-system"
      }
      data = {
        network = base64encode(local.hcloud_network_id)
        token   = base64encode(var.hcloud_token)
      }
    })
  }
  hcloud_csi_storage_class_encryption_key_manifest = var.hcloud_csi_enabled ? var.hcloud_csi_storage_class_encryption_enabled ? {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "hcloud-csi-secret"
      namespace = "kube-system"
    }
    data = {
      encryption-passphrase = var.hcloud_csi_storage_class_encryption_key != null ? base64encode(var.hcloud_csi_storage_class_encryption_key) : base64encode(random_bytes.hcloud_csi_encryption_key[0].hex)
    }
  } : null : null
  hcloud_csi_default_storage_class = [
    {
      name                = "hcloud-volumes"
      defaultStorageClass = true
      reclaimPolicy       = var.hcloud_csi_storage_class_reclaim_policy
      extraParameters = merge(
        var.hcloud_csi_storage_class_encryption_enabled ? {
          "csi.storage.k8s.io/node-publish-secret-name"      = "hcloud-csi-secret"
          "csi.storage.k8s.io/node-publish-secret-namespace" = "kube-system"
        } : {},
        var.hcloud_csi_storage_class_extra_parameters
      )
    }
  ]
}

# Hcloud CCM
data "helm_template" "hcloud_ccm" {
  name      = "hcloud-cloud-controller-manager"
  namespace = "kube-system"

  repository   = var.hcloud_ccm_helm_repository
  chart        = var.hcloud_ccm_helm_chart
  version      = var.hcloud_ccm_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      kind         = "DaemonSet"
      nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
      networking = {
        enabled     = true
        clusterCIDR = local.pod_ipv4_cidr
      }
      env = {
        HCLOUD_LOAD_BALANCERS_USE_PRIVATE_IP          = { value = "true" }
        HCLOUD_LOAD_BALANCERS_DISABLE_PRIVATE_INGRESS = { value = "true" }
        HCLOUD_LOAD_BALANCERS_LOCATION                = { value = local.hcloud_load_balancer_location }
      }
    }),
    yamlencode(var.hcloud_ccm_helm_values)
  ]
}

locals {
  hcloud_ccm_manifest = var.hcloud_ccm_enabled ? {
    name     = "hcloud-ccm"
    contents = data.helm_template.hcloud_ccm.manifest
  } : null
}

# Hcloud CSI
resource "random_bytes" "hcloud_csi_encryption_key" {
  count  = var.hcloud_csi_enabled ? var.hcloud_csi_storage_class_encryption_enabled ? var.hcloud_csi_storage_class_encryption_key == null ? 1 : 0 : 0 : 0
  length = 32
}

data "helm_template" "hcloud_csi" {
  count = var.hcloud_csi_enabled ? 1 : 0

  name      = "hcloud-csi"
  namespace = "kube-system"

  repository   = var.hcloud_csi_helm_repository
  chart        = var.hcloud_csi_helm_chart
  version      = var.hcloud_csi_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      controller = {
        replicaCount = local.control_plane_sum > 1 ? 2 : 1
        topologySpreadConstraints = [
          {
            topologyKey       = "kubernetes.io/hostname"
            maxSkew           = 1
            whenUnsatisfiable = local.control_plane_sum > 2 ? "DoNotSchedule" : "ScheduleAnyway"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/name"      = "hcloud-csi"
                "app.kubernetes.io/instance"  = "hcloud-csi"
                "app.kubernetes.io/component" = "controller"
              }
            }
          }
        ]
        nodeSelector = { "node-role.kubernetes.io/control-plane" : "" }
        tolerations = [
          {
            key      = "node-role.kubernetes.io/control-plane"
            effect   = "NoSchedule"
            operator = "Exists"
          }
        ]
        volumeExtraLabels = var.hcloud_csi_volume_extra_labels
      }
      storageClasses = concat(local.hcloud_csi_default_storage_class, var.hcloud_csi_additional_storage_classes)
    }),
    yamlencode(var.hcloud_csi_helm_values)
  ]
}

locals {
  hcloud_csi_manifest = var.hcloud_csi_enabled ? {
    name     = "hcloud-csi"
    contents = <<-EOF
      ${data.helm_template.hcloud_csi[0].manifest}
      ---
      ${var.hcloud_csi_storage_class_encryption_enabled ? yamlencode(local.hcloud_csi_storage_class_encryption_key_manifest) : yamlencode({})}
    EOF
  } : null
}
