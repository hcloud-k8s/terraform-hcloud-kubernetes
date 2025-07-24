locals {
  # Create bindings for OIDC groups
  oidc_manifests = var.oidc_enabled ? concat(

    # Cluster Role bindings
    flatten([
      for oidc_group, mapping in var.oidc_group_mappings : [
        for cluster_role in mapping.cluster_roles : yamlencode({
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "ClusterRoleBinding"
          metadata = {
            name = "${oidc_group}-${cluster_role}"
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "ClusterRole"
            name     = cluster_role
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "${var.oidc_groups_prefix}${oidc_group}"
            }
          ]
        })
      ]
    ]),

    # Role bindings
    flatten([
      for oidc_group, mapping in var.oidc_group_mappings : [
        for role in mapping.roles : yamlencode({
          apiVersion = "rbac.authorization.k8s.io/v1"
          kind       = "RoleBinding"
          metadata = {
            name      = "${oidc_group}-${role.name}"
            namespace = role.namespace
          }
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io"
            kind     = "Role"
            name     = role.name
          }
          subjects = [
            {
              apiGroup = "rbac.authorization.k8s.io"
              kind     = "Group"
              name     = "${var.oidc_groups_prefix}${oidc_group}"
            }
          ]
        })
      ]
    ])
  ) : []

  oidc_manifest = length(local.oidc_manifests) > 0 ? {
    name     = "talos-oidc"
    contents = join("\n---\n", local.oidc_manifests)
  } : null
}