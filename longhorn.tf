locals {
  longhorn_namespace = var.longhorn_enabled ? {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = data.helm_template.longhorn[0].namespace
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
        "pod-security.kubernetes.io/audit"   = "privileged"
        "pod-security.kubernetes.io/warn"    = "privileged"
      }
    }
  } : null
}

data "helm_template" "longhorn" {
  count = var.longhorn_enabled ? 1 : 0

  name      = "longhorn"
  namespace = "longhorn-system"

  repository   = var.longhorn_helm_repository
  chart        = var.longhorn_helm_chart
  version      = var.longhorn_helm_version
  kube_version = var.kubernetes_version

  disable_webhooks = true

  values = [
    yamlencode({
      defaultSettings = {
        allowCollectingLonghornUsageMetrics = false
        kubernetesClusterAutoscalerEnabled  = local.cluster_autoscaler_enabled
        upgradeChecker                      = false
      }
      networkPolicies = {
        enabled = true
        type    = "rke1" # rke1 = ingress-nginx
      }
      persistence = {
        defaultClass = var.longhorn_default_storage_class
      }
    }),
    yamlencode(var.longhorn_helm_values)
  ]
}

locals {
  longhorn_manifest = var.longhorn_enabled ? {
    name     = "longhorn"
    contents = <<-EOF
      ${yamlencode(local.longhorn_namespace)}
      ---
      ${data.helm_template.longhorn[0].manifest}
    EOF
  } : null
}
