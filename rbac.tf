locals {
  # Generate Kubernetes RBAC manifests
  kube_rbac_manifests = concat(

    # Kubernetes namespaced roles
    [for role in var.rbac_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = role.name
        namespace = role.namespace
      }
      rules = [for rule in role.rules : {
        apiGroups = rule.api_groups
        resources = rule.resources
        verbs     = rule.verbs
      }]
    })],

    # Kubernetes cluster roles 
    [for role in var.rbac_cluster_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = role.name
      }
      rules = [for rule in role.rules : {
        apiGroups = rule.api_groups
        resources = rule.resources
        verbs     = rule.verbs
      }]
    })]
  )

  # Final manifest
  kube_rbac_manifest = length(local.kube_rbac_manifests) > 0 ? {
    name     = "kube-rbac"
    contents = trimspace(join("\n---\n", local.kube_rbac_manifests))
  } : null
}

