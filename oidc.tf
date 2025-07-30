locals {
  # Collect all unique k8s cluster roles used across OIDC group mappings
  k8s_cluster_roles = var.oidc_enabled ? toset(flatten([
    for group_mapping in var.oidc_group_mappings : group_mapping.cluster_roles
  ])) : toset([])

  # Collect all unique k8s roles used across OIDC group mappings (grouped by namespace/role)
  k8s_roles = var.oidc_enabled ? {
    for role_key, role_info in merge([
      for group_mapping in var.oidc_group_mappings : {
        for role in group_mapping.roles : "${role.namespace}/${role.name}" => role
      }
    ]...) : role_key => role_info
  } : {}

  # Create one ClusterRoleBinding per cluster role with all groups as subjects
  cluster_role_binding_manifests = [
    for cluster_role in local.k8s_cluster_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = "oidc-${cluster_role}"
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "ClusterRole"
        name     = cluster_role
      }
      subjects = [
        for group_mapping in var.oidc_group_mappings : {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "Group"
          name     = "${var.oidc_groups_prefix}${group_mapping.group}"
        }
        if contains(group_mapping.cluster_roles, cluster_role)
      ]
    })
    if length([
      for group_mapping in var.oidc_group_mappings : group_mapping
      if contains(group_mapping.cluster_roles, cluster_role)
    ]) > 0
  ]

  # Create one RoleBinding per role with all groups as subjects
  role_binding_manifests = [
    for role_key, role_info in local.k8s_roles : yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name      = "oidc-${role_info.name}"
        namespace = role_info.namespace
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Role"
        name     = role_info.name
      }
      subjects = [
        for group_mapping in var.oidc_group_mappings : {
          apiGroup = "rbac.authorization.k8s.io"
          kind     = "Group"
          name     = "${var.oidc_groups_prefix}${group_mapping.group}"
        }
        if contains([for role in group_mapping.roles : "${role.namespace}/${role.name}"], role_key)
      ]
    })
    if length([
      for group_mapping in var.oidc_group_mappings : group_mapping
      if contains([for role in group_mapping.roles : "${role.namespace}/${role.name}"], role_key)
    ]) > 0
  ]

  # Combine all OIDC manifests
  oidc_manifests = var.oidc_enabled ? concat(
    local.cluster_role_binding_manifests,
    local.role_binding_manifests
  ) : []

  # Final manifest
  oidc_manifest = length(local.oidc_manifests) > 0 ? {
    name     = "kube-oidc-rbac"
    contents = join("\n---\n", local.oidc_manifests)
  } : null
}
