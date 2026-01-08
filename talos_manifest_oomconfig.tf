locals {
  # OOMConfig document - Out of Memory handler configuration
  # The OOM handler is always enabled by default in Talos 1.12+ with built-in defaults
  # This document is only generated when custom OOM configuration is requested
  talos_manifest_oomconfig = var.talos_custom_oom_enabled ? yamlencode(
    merge(
      {
        apiVersion = "v1alpha1"
        kind       = "OOMConfig"
      },
      var.talos_custom_oom_trigger_expression != "" ? { triggerExpression = var.talos_custom_oom_trigger_expression } : {},
      var.talos_custom_oom_cgroup_ranking_expression != "" ? { cgroupRankingExpression = var.talos_custom_oom_cgroup_ranking_expression } : {},
      var.talos_custom_oom_sample_interval != "" ? { sampleInterval = var.talos_custom_oom_sample_interval } : {}
    )
  ) : null
}
