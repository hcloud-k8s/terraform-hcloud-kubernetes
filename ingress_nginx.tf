locals {
  ingress_nginx_namespace = var.ingress_nginx_enabled ? {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = data.helm_template.ingress_nginx[0].namespace
    }
  } : null

  ingress_nginx_replicas = coalesce(
    var.ingress_nginx_replicas,
    local.worker_sum < 4 ? 2 : 3
  )

  ingress_nginx_service_load_balancer_required = (
    var.ingress_nginx_enabled &&
    length(var.ingress_load_balancer_pools) == 0
  )
  ingress_nginx_service_type = (
    local.ingress_nginx_service_load_balancer_required ?
    "LoadBalancer" :
    "NodePort"
  )
  ingress_nginx_service_node_port_http  = 30000
  ingress_nginx_service_node_port_https = 30001
}

data "helm_template" "ingress_nginx" {
  count = var.ingress_nginx_enabled ? 1 : 0

  name      = "ingress-nginx"
  namespace = "ingress-nginx"

  repository   = var.ingress_nginx_helm_repository
  chart        = var.ingress_nginx_helm_chart
  version      = var.ingress_nginx_helm_version
  kube_version = var.kubernetes_version

  set = [
    {
      name  = "controller.admissionWebhooks.certManager.enabled"
      value = true
    }
  ]

  values = [
    yamlencode({
      controller = {
        kind         = var.ingress_nginx_kind
        replicaCount = local.ingress_nginx_replicas
        topologySpreadConstraints = [
          {
            topologyKey = "kubernetes.io/hostname"
            maxSkew     = 1
            whenUnsatisfiable = (
              local.worker_sum > local.ingress_nginx_replicas ?
              "DoNotSchedule" :
              "ScheduleAnyway"
            )
            labelSelector = {
              matchLabels = {
                "app.kubernetes.io/instance"  = "ingress-nginx"
                "app.kubernetes.io/name"      = "ingress-nginx"
                "app.kubernetes.io/component" = "controller"
              }
            }
          }
        ]
        enableTopologyAwareRouting = var.ingress_nginx_topology_aware_routing
        watchIngressWithoutClass   = true
        service = merge(
          {
            type                  = local.ingress_nginx_service_type
            externalTrafficPolicy = var.ingress_nginx_service_external_traffic_policy
          },
          local.ingress_nginx_service_type == "NodePort" ?
          {
            nodePorts = {
              http  = local.ingress_nginx_service_node_port_http,
              https = local.ingress_nginx_service_node_port_https
            }
          } : {},
          local.ingress_nginx_service_type == "LoadBalancer" ?
          {
            annotations = {
              "load-balancer.hetzner.cloud/algorithm-type"          = var.ingress_load_balancer_algorithm
              "load-balancer.hetzner.cloud/disable-private-ingress" = true
              "load-balancer.hetzner.cloud/disable-public-network"  = !var.ingress_load_balancer_public_network_enabled
              "load-balancer.hetzner.cloud/health-check-interval"   = "${var.ingress_load_balancer_health_check_interval}s"
              "load-balancer.hetzner.cloud/health-check-retries"    = var.ingress_load_balancer_health_check_retries
              "load-balancer.hetzner.cloud/health-check-timeout"    = "${var.ingress_load_balancer_health_check_timeout}s"
              "load-balancer.hetzner.cloud/hostname"                = local.ingress_service_load_balancer_hostname
              "load-balancer.hetzner.cloud/ipv6-disabled"           = false
              "load-balancer.hetzner.cloud/location"                = local.ingress_service_load_balancer_location
              "load-balancer.hetzner.cloud/name"                    = local.ingress_service_load_balancer_name
              "load-balancer.hetzner.cloud/type"                    = var.ingress_load_balancer_type
              "load-balancer.hetzner.cloud/use-private-ip"          = true
              "load-balancer.hetzner.cloud/uses-proxyprotocol"      = true
            }
          } : {}
        )
        config = merge(
          {
            proxy-real-ip-cidr = (
              var.ingress_nginx_service_external_traffic_policy == "Local" ?
              hcloud_network_subnet.load_balancer.ip_range :
              local.node_ipv4_cidr
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
  ingress_nginx_manifest = var.ingress_nginx_enabled ? {
    name     = "ingress-nginx"
    contents = <<-EOF
      ${yamlencode(local.ingress_nginx_namespace)}
      ---
      ${data.helm_template.ingress_nginx[0].manifest}
    EOF
  } : null
}
