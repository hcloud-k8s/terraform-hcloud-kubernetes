locals {
  external_dns_namespace = var.external_dns.enabled ? {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = var.external_dns.namespace
    }
  } : null

  external_dns_secret_manifest = var.external_dns.enabled ? {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "external-dns-hcloud"
      namespace = var.external_dns.namespace
    }
    data = {
      api-token = base64encode(var.hcloud_token)
    }
  } : null

  external_dns_txt_owner_id = coalesce(var.external_dns.txt_owner_id, var.cluster_name)
}

data "helm_template" "external_dns" {
  count = var.external_dns.enabled ? 1 : 0

  name      = "external-dns"
  namespace = var.external_dns.namespace

  repository   = var.external_dns.helm.repository
  chart        = var.external_dns.helm.chart
  version      = var.external_dns.helm.version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      provider = {
        name = "webhook"
        webhook = {
          image = {
            repository = var.external_dns.webhook.image_repository
            tag        = var.external_dns.webhook.image_tag
            pullPolicy = "IfNotPresent"
          }
          env = [
            {
              name = "HETZNER_API_KEY"
              valueFrom = {
                secretKeyRef = {
                  name = "external-dns-hcloud"
                  key  = "api-token"
                }
              }
            },
            {
              name  = "USE_CLOUD_API"
              value = var.external_dns.webhook.use_cloud_api ? "true" : "false"
            }
          ]
          livenessProbe = {
            httpGet = {
              path = "/health"
              port = "http-webhook"
            }
            initialDelaySeconds = 10
            timeoutSeconds      = 5
          }
          readinessProbe = {
            httpGet = {
              path = "/ready"
              port = "http-webhook"
            }
            initialDelaySeconds = 10
            timeoutSeconds      = 5
          }
        }
      }
      sources       = var.external_dns.sources
      domainFilters = var.external_dns.domain_filters
      txtOwnerId    = local.external_dns_txt_owner_id
      txtPrefix     = var.external_dns.txt_prefix
      policy        = var.external_dns.policy
      registry      = var.external_dns.registry
      interval      = var.external_dns.interval
      extraArgs = {
        "webhook-provider-url" = "http://localhost:8888"
      }
    }),
    yamlencode(var.external_dns.helm.values)
  ]
}

locals {
  external_dns_manifest = var.external_dns.enabled ? {
    name     = "external-dns"
    contents = <<-EOF
      ${yamlencode(local.external_dns_namespace)}
      ---
      ${yamlencode(local.external_dns_secret_manifest)}
      ---
      ${data.helm_template.external_dns[0].manifest}
    EOF
  } : null
}
