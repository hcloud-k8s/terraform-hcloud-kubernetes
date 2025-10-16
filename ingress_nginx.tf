locals {
  ingress_nginx_enabled = var.ingress_controller_type == "nginx"
  ingress_nginx_namespace = local.ingress_nginx_enabled ? {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = data.helm_template.ingress_nginx[0].namespace
    }
  } : null

  ingress_nginx_replicas = coalesce(
    var.ingress_nginx_replicas,
    local.worker_sum < 3 ? 2 : 3
  )
}

data "helm_template" "ingress_nginx" {
  count = local.ingress_nginx_enabled ? 1 : 0

  name      = "ingress-nginx"
  namespace = "ingress-nginx"

  repository   = var.ingress_nginx_helm_repository
  chart        = var.ingress_nginx_helm_chart
  version      = var.ingress_nginx_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      controller = {
        admissionWebhooks = {
          certManager = {
            enabled = true
          }
        }
        kind           = var.ingress_nginx_kind
        replicaCount   = local.ingress_nginx_replicas
        minAvailable   = null
        maxUnavailable = 1
        topologySpreadConstraints = var.ingress_nginx_kind == "Deployment" ? [
          {
            topologyKey       = "kubernetes.io/hostname"
            maxSkew           = 1
            whenUnsatisfiable = local.worker_sum > 1 ? "DoNotSchedule" : "ScheduleAnyway"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/instance"  = "ingress-nginx"
                "app.kubernetes.io/name"      = "ingress-nginx"
                "app.kubernetes.io/component" = "controller"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          },
          {
            topologyKey       = "topology.kubernetes.io/zone"
            maxSkew           = 1
            whenUnsatisfiable = "ScheduleAnyway"
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/instance"  = "ingress-nginx"
                "app.kubernetes.io/name"      = "ingress-nginx"
                "app.kubernetes.io/component" = "controller"
              }
            }
            matchLabelKeys = ["pod-template-hash"]
          }
        ] : []
        enableTopologyAwareRouting = var.ingress_nginx_topology_aware_routing
        watchIngressWithoutClass   = true
        service = merge(
          {
            type                  = local.ingress_service_type
            externalTrafficPolicy = var.ingress_service_external_traffic_policy
          },
          local.ingress_service_type == "NodePort" ?
          {
            nodePorts = {
              http  = var.ingress_service_node_port_http
              https = var.ingress_service_node_port_https
            }
          } : {},
          local.ingress_service_type == "LoadBalancer" ?
          {
            annotations = local.ingress_load_balancer_annotations
          } : {}
        )
        config = merge(
          {
            proxy-real-ip-cidr = (
              var.ingress_service_external_traffic_policy == "Local" ?
              hcloud_network_subnet.load_balancer.ip_range :
              local.network_node_ipv4_cidr
            )
            compute-full-forwarded-for = true
            use-proxy-protocol         = true
          },
          var.ingress_nginx_config
        )
        networkPolicy = {
          enabled = true
        }
      }
    }),
    yamlencode(var.ingress_nginx_helm_values)
  ]

  depends_on = [hcloud_load_balancer_network.ingress]
}

locals {
  ingress_nginx_manifest = local.ingress_nginx_enabled ? {
    name     = "ingress-nginx"
    contents = <<-EOF
      ${yamlencode(local.ingress_nginx_namespace)}
      ---
      ${data.helm_template.ingress_nginx[0].manifest}
    EOF
  } : null
}
