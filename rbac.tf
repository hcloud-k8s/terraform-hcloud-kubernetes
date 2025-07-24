locals {
  # Generate Kubernetes RBAC manifests
  rbac_manifests = concat(
    # Kubernetes namespaced roles
    [for role_name, role_config in var.rbac_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "Role"
      metadata = {
        name      = role_name
        namespace = role_config.namespace
      }
      rules = [for rule in role_config.rules : {
        apiGroups = rule.api_groups
        resources = rule.resources
        verbs     = rule.verbs
      }]
    })],
    # Kubernetes cluster roles 
    [for role_name, role_config in var.rbac_cluster_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRole"
      metadata = {
        name = role_name
      }
      rules = [for rule in role_config.rules : {
        apiGroups = rule.api_groups
        resources = rule.resources
        verbs     = rule.verbs
      }]
    })]
  )

  rbac_manifest = length(local.rbac_manifests) > 0 ? {
    name     = "talos-rbac"
    contents = join("\n---\n", local.rbac_manifests)
  } : null
}

