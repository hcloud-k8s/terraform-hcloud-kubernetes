data "helm_template" "talos_ccm" {
  count = var.talos_ccm_enabled ? 1 : 0

  name      = "talos-cloud-controller-manager"
  namespace = "kube-system"

  repository   = var.talos_ccm_helm_repository
  chart        = var.talos_ccm_helm_chart
  version      = var.talos_ccm_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      enabledControllers = [
        "node-csr-approval"
      ]
      daemonSet = {
        enabled = true
      }
    }),
    yamlencode(var.talos_ccm_helm_values)
  ]
}

locals {
  talos_ccm_manifest = var.talos_ccm_enabled ? {
    name     = "talos-ccm"
    contents = data.helm_template.talos_ccm[0].manifest
  } : null
}
