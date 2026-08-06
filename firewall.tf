locals {
  firewall_external = var.firewall_id != null

  firewall_kube_api_source = (
    var.firewall_kube_api_source != null ?
    var.firewall_kube_api_source :
    var.firewall_api_source
  )
  firewall_talos_api_source = (
    var.firewall_talos_api_source != null ?
    var.firewall_talos_api_source :
    var.firewall_api_source
  )

  firewall_use_current_ipv4 = !local.firewall_external && local.network_public_ipv4_enabled && coalesce(
    var.firewall_use_current_ipv4,
    var.cluster_access == "public" && local.firewall_kube_api_source == null && local.firewall_talos_api_source == null
  )
  firewall_use_current_ipv6 = !local.firewall_external && local.network_public_ipv6_enabled && coalesce(
    var.firewall_use_current_ipv6,
    var.cluster_access == "public" && local.firewall_kube_api_source == null && local.firewall_talos_api_source == null
  )

  current_ip = concat(
    local.firewall_use_current_ipv4 ? ["${chomp(data.http.current_ipv4[0].response_body)}/32"] : [],
    local.firewall_use_current_ipv6 ? (
      strcontains(data.http.current_ipv6[0].response_body, ":") ?
      [cidrsubnet("${chomp(data.http.current_ipv6[0].response_body)}/64", 0, 0)] :
      []
    ) : []
  )

  robot_firewall_base_curl_data = [
    "status=active",
    "whitelist_hos=true",
    "filter_ipv6=true"
  ]
  robot_firewall_rule_fields = [
    "name",
    "ip_version",
    "protocol",
    "dst_port",
    "tcp_flags",
    "src_ip",
    "dst_ip",
    "action"
  ]

  bare_metal_initialization_firewall_rule_fields = [
    for field in local.robot_firewall_rule_fields : field if field != "dst_ip"
  ]

  bare_metal_initialization_firewall_configured_sources = coalesce(local.firewall_talos_api_source, [])
  bare_metal_initialization_firewall_configured_ipv4_sources = [
    for source in local.bare_metal_initialization_firewall_configured_sources : source
    if !strcontains(source, ":")
  ]
  bare_metal_initialization_firewall_configured_ipv6_sources = [
    for source in local.bare_metal_initialization_firewall_configured_sources : source
    if strcontains(source, ":")
  ]

  bare_metal_initialization_firewall_use_current_ipv4 = local.bare_metal_enabled && coalesce(var.firewall_use_current_ipv4, length(local.bare_metal_initialization_firewall_configured_ipv4_sources) == 0)
  bare_metal_initialization_firewall_current_ipv4_sources = (
    local.bare_metal_initialization_firewall_use_current_ipv4 ?
    ["${chomp(data.http.current_ipv4[0].response_body)}/32"] :
    []
  )
  bare_metal_initialization_firewall_ipv4_sources = distinct(compact(concat(
    local.bare_metal_initialization_firewall_configured_ipv4_sources,
    local.bare_metal_initialization_firewall_current_ipv4_sources
  )))
  bare_metal_initialization_firewall_ipv4_available = length(local.bare_metal_initialization_firewall_ipv4_sources) > 0

  bare_metal_initialization_firewall_use_current_ipv6 = local.bare_metal_enabled && !local.bare_metal_initialization_firewall_ipv4_available && coalesce(var.firewall_use_current_ipv6, length(local.bare_metal_initialization_firewall_configured_ipv6_sources) == 0)
  bare_metal_initialization_firewall_current_ipv6_sources = (
    local.bare_metal_initialization_firewall_use_current_ipv6 ? (
      strcontains(data.http.current_ipv6[0].response_body, ":") ?
      [cidrsubnet("${chomp(data.http.current_ipv6[0].response_body)}/64", 0, 0)] :
      []
    ) :
    []
  )
  bare_metal_initialization_firewall_ipv6_sources = local.bare_metal_initialization_firewall_ipv4_available ? [] : distinct(compact(concat(
    local.bare_metal_initialization_firewall_configured_ipv6_sources,
    local.bare_metal_initialization_firewall_current_ipv6_sources
  )))
  bare_metal_initialization_firewall_ipv6_enabled = length(local.bare_metal_initialization_firewall_ipv6_sources) > 0

  bare_metal_initialization_firewall_service_rules = concat(
    [
      for source_index, source in local.bare_metal_initialization_firewall_ipv4_sources : {
        name       = "Allow SSH IPv4 ${source_index + 1}"
        ip_version = "ipv4"
        protocol   = "tcp"
        dst_port   = "22"
        tcp_flags  = null
        src_ip     = source
        action     = "accept"
      }
    ],
    # Robot firewall IPv6 rules cannot filter source IPs, so IPv6 is fallback-only.
    local.bare_metal_initialization_firewall_ipv6_enabled ? [
      {
        name       = "Allow SSH IPv6"
        ip_version = "ipv6"
        protocol   = "tcp"
        dst_port   = "22"
        tcp_flags  = null
        src_ip     = null
        action     = "accept"
      }
    ] : []
  )

  bare_metal_initialization_firewall_input_rules = concat(
    [
      {
        name       = "Allow established TCP"
        ip_version = ""
        protocol   = null
        dst_port   = "32768-65535"
        tcp_flags  = "ack"
        src_ip     = null
        action     = "accept"
      },
    ],
    local.bare_metal_initialization_firewall_service_rules
  )

  bare_metal_initialization_firewall_output_rules = [
    {
      name       = "Allow all"
      ip_version = null
      protocol   = null
      dst_port   = null
      tcp_flags  = null
      src_ip     = null
      action     = "accept"
    },
  ]

  bare_metal_initialization_firewall_rules = {
    input  = local.bare_metal_initialization_firewall_input_rules
    output = local.bare_metal_initialization_firewall_output_rules
  }

  bare_metal_initialization_firewall_curl_data = concat(
    local.robot_firewall_base_curl_data,
    flatten([
      for direction, rules in local.bare_metal_initialization_firewall_rules : [
        for i, rule in rules : compact([
          for field in local.bare_metal_initialization_firewall_rule_fields :
          lookup(rule, field, null) != null ? "rules[${direction}][${i}][${field}]=${lookup(rule, field, null)}" : null
        ])
      ]
    ])
  )

  bare_metal_firewall_configured_sources = distinct(compact(concat(
    coalesce(local.firewall_kube_api_source, []),
    coalesce(local.firewall_talos_api_source, [])
  )))
  bare_metal_firewall_configured_ipv4_sources = [
    for source in local.bare_metal_firewall_configured_sources : source
    if !strcontains(source, ":")
  ]
  bare_metal_firewall_configured_ipv6_sources = [
    for source in local.bare_metal_firewall_configured_sources : source
    if strcontains(source, ":")
  ]
  bare_metal_firewall_use_current_ipv4 = local.bare_metal_enabled && coalesce(var.firewall_use_current_ipv4, length(local.bare_metal_firewall_configured_ipv4_sources) == 0)
  bare_metal_firewall_current_ipv4_sources = (
    local.bare_metal_firewall_use_current_ipv4 ?
    ["${chomp(data.http.current_ipv4[0].response_body)}/32"] :
    []
  )
  bare_metal_firewall_ipv4_available = length(local.bare_metal_firewall_configured_ipv4_sources) > 0 || local.bare_metal_firewall_use_current_ipv4

  bare_metal_firewall_use_current_ipv6 = local.bare_metal_enabled && !local.bare_metal_firewall_ipv4_available && coalesce(var.firewall_use_current_ipv6, length(local.bare_metal_firewall_configured_ipv6_sources) == 0)
  bare_metal_firewall_current_ipv6_sources = (
    local.bare_metal_firewall_use_current_ipv6 ? (
      strcontains(data.http.current_ipv6[0].response_body, ":") ?
      [cidrsubnet("${chomp(data.http.current_ipv6[0].response_body)}/64", 0, 0)] :
      []
    ) :
    []
  )
  bare_metal_firewall_kube_api_configured_ipv4_sources = [
    for source in coalesce(local.firewall_kube_api_source, []) : source
    if !strcontains(source, ":")
  ]
  bare_metal_firewall_kube_api_configured_ipv6_sources = [
    for source in coalesce(local.firewall_kube_api_source, []) : source
    if strcontains(source, ":")
  ]
  bare_metal_firewall_talos_api_configured_ipv4_sources = [
    for source in coalesce(local.firewall_talos_api_source, []) : source
    if !strcontains(source, ":")
  ]
  bare_metal_firewall_talos_api_configured_ipv6_sources = [
    for source in coalesce(local.firewall_talos_api_source, []) : source
    if strcontains(source, ":")
  ]
  bare_metal_firewall_kube_api_sources = distinct(compact(concat(
    local.bare_metal_firewall_ipv4_available ? local.bare_metal_firewall_kube_api_configured_ipv4_sources : local.bare_metal_firewall_kube_api_configured_ipv6_sources,
    local.bare_metal_firewall_ipv4_available ? local.bare_metal_firewall_current_ipv4_sources : local.bare_metal_firewall_current_ipv6_sources
  )))
  bare_metal_firewall_talos_api_sources = distinct(compact(concat(
    local.bare_metal_firewall_ipv4_available ? local.bare_metal_firewall_talos_api_configured_ipv4_sources : local.bare_metal_firewall_talos_api_configured_ipv6_sources,
    local.bare_metal_firewall_ipv4_available ? local.bare_metal_firewall_current_ipv4_sources : local.bare_metal_firewall_current_ipv6_sources
  )))
  bare_metal_firewall_kube_api_ipv4_sources = [
    for source in local.bare_metal_firewall_kube_api_sources : source
    if !strcontains(source, ":")
  ]
  bare_metal_firewall_kube_api_ipv6_enabled = anytrue([
    for source in local.bare_metal_firewall_kube_api_sources : strcontains(source, ":")
  ])
  bare_metal_firewall_talos_api_ipv4_sources = [
    for source in local.bare_metal_firewall_talos_api_sources : source
    if !strcontains(source, ":")
  ]
  bare_metal_firewall_talos_api_ipv6_enabled = anytrue([
    for source in local.bare_metal_firewall_talos_api_sources : strcontains(source, ":")
  ])

  bare_metal_firewall_extra_input_rules = flatten([
    for rule in var.firewall_extra_rules : rule.direction == "in" ? (
      length(rule.source_ips) == 0 ? [
        {
          name       = "${rule.description} IPv4"
          ip_version = "ipv4"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = null
          dst_ip     = null
          action     = "accept"
        },
        {
          name       = "${rule.description} IPv6"
          ip_version = "ipv6"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = null
          dst_ip     = null
          action     = "accept"
        },
        ] : [
        for source_index, source in [for source in rule.source_ips : source if !strcontains(source, ":")] : {
          name       = "${rule.description} ${source_index + 1}"
          ip_version = "ipv4"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = source
          dst_ip     = null
          action     = "accept"
        }
      ]
    ) : []
  ])

  bare_metal_firewall_extra_output_rules = flatten([
    for rule in var.firewall_extra_rules : rule.direction == "out" ? (
      length(rule.destination_ips) == 0 ? [
        {
          name       = "${rule.description} IPv4"
          ip_version = "ipv4"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = null
          dst_ip     = null
          action     = "accept"
        },
        {
          name       = "${rule.description} IPv6"
          ip_version = "ipv6"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = null
          dst_ip     = null
          action     = "accept"
        },
        ] : [
        for destination_index, destination in [for destination in rule.destination_ips : destination if !strcontains(destination, ":")] : {
          name       = "${rule.description} ${destination_index + 1}"
          ip_version = "ipv4"
          protocol   = rule.protocol
          dst_port   = lookup(rule, "port", null)
          tcp_flags  = null
          src_ip     = null
          dst_ip     = destination
          action     = "accept"
        }
      ]
    ) : []
  ])
  bare_metal_firewall_extra_output_rules_configured = anytrue([
    for rule in var.firewall_extra_rules : rule.direction == "out"
  ])

  bare_metal_firewall_input_rules = concat(
    [
      {
        name       = "Allow established TCP"
        ip_version = ""
        protocol   = null
        dst_port   = "32768-65535"
        tcp_flags  = "ack"
        src_ip     = null
        dst_ip     = null
        action     = "accept"
      },
      {
        name       = "Allow internal network"
        ip_version = "ipv4"
        protocol   = null
        dst_port   = null
        tcp_flags  = null
        src_ip     = local.network_ipv4_cidr
        dst_ip     = null
        action     = "accept"
      },
    ],
    [
      for source_index, source in local.bare_metal_firewall_kube_api_ipv4_sources : {
        name       = "Allow Kube API IPv4 ${source_index + 1}"
        ip_version = "ipv4"
        protocol   = "tcp"
        dst_port   = tostring(local.kube_api_port)
        tcp_flags  = null
        src_ip     = source
        dst_ip     = null
        action     = "accept"
      }
    ],
    local.bare_metal_firewall_kube_api_ipv6_enabled ? [
      {
        name       = "Allow Kube API IPv6"
        ip_version = "ipv6"
        protocol   = "tcp"
        dst_port   = tostring(local.kube_api_port)
        tcp_flags  = null
        src_ip     = null
        dst_ip     = null
        action     = "accept"
      },
    ] : [],
    [
      for source_index, source in local.bare_metal_firewall_talos_api_ipv4_sources : {
        name       = "Allow Talos API IPv4 ${source_index + 1}"
        ip_version = "ipv4"
        protocol   = "tcp"
        dst_port   = tostring(local.talos_api_port)
        tcp_flags  = null
        src_ip     = source
        dst_ip     = null
        action     = "accept"
      }
    ],
    local.bare_metal_firewall_talos_api_ipv6_enabled ? [
      {
        name       = "Allow Talos API IPv6"
        ip_version = "ipv6"
        protocol   = "tcp"
        dst_port   = tostring(local.talos_api_port)
        tcp_flags  = null
        src_ip     = null
        dst_ip     = null
        action     = "accept"
      },
    ] : [],
    local.bare_metal_firewall_extra_input_rules
  )

  bare_metal_firewall_output_rules = concat(
    [
      {
        name       = "Allow internal network"
        ip_version = "ipv4"
        protocol   = null
        dst_port   = null
        tcp_flags  = null
        src_ip     = null
        dst_ip     = local.network_ipv4_cidr
        action     = "accept"
      },
    ],
    local.bare_metal_firewall_extra_output_rules_configured ? local.bare_metal_firewall_extra_output_rules : [
      {
        name       = "Allow all"
        ip_version = null
        protocol   = null
        dst_port   = null
        tcp_flags  = null
        src_ip     = null
        dst_ip     = null
        action     = "accept"
      },
    ]
  )

  bare_metal_firewall_rules = {
    input  = local.bare_metal_firewall_input_rules
    output = local.bare_metal_firewall_output_rules
  }

  bare_metal_firewall_curl_data = concat(
    local.robot_firewall_base_curl_data,
    flatten([
      for direction, rules in local.bare_metal_firewall_rules : [
        for i, rule in rules : compact([
          for field in local.robot_firewall_rule_fields :
          lookup(rule, field, null) != null ? "rules[${direction}][${i}][${field}]=${lookup(rule, field, null)}" : null
        ])
      ]
    ])
  )

  firewall_kube_api_sources = distinct(compact(concat(
    coalesce(local.firewall_kube_api_source, []),
    coalesce(local.current_ip, [])
  )))
  firewall_talos_api_sources = distinct(compact(concat(
    coalesce(local.firewall_talos_api_source, []),
    coalesce(local.current_ip, [])
  )))

  firewall_default_rules = concat(
    length(local.firewall_kube_api_sources) > 0 ? [
      {
        description = "Allow Incoming Requests to Kube API"
        direction   = "in"
        source_ips  = local.firewall_kube_api_sources
        protocol    = "tcp"
        port        = local.kube_api_port
      }
    ] : [],
    length(local.firewall_talos_api_sources) > 0 ? [
      {
        description = "Allow Incoming Requests to Talos API"
        direction   = "in"
        source_ips  = local.firewall_talos_api_sources
        protocol    = "tcp"
        port        = local.talos_api_port
      }
    ] : [],
  )

  firewall_rules = {
    for rule in local.firewall_default_rules :
    format("%s-%s-%s",
      lookup(rule, "direction", "null"),
      lookup(rule, "protocol", "null"),
      lookup(rule, "port", "null")
    ) => rule
  }
  firewall_extra_rules = {
    for rule in [
      for rule in var.firewall_extra_rules : merge(
        rule,
        rule.direction == "in" ? {
          source_ips = length(rule.source_ips) == 0 ? ["0.0.0.0/0", "::/0"] : rule.source_ips
          } : {
          destination_ips = length(rule.destination_ips) == 0 ? ["0.0.0.0/0", "::/0"] : rule.destination_ips
        }
      )
    ] :
    format("%s-%s-%s",
      lookup(rule, "direction", "null"),
      lookup(rule, "protocol", "null"),
      coalesce(lookup(rule, "port", "null"), "null")
    ) => rule
  }

  firewall_rules_list = values(
    merge(local.firewall_extra_rules, local.firewall_rules)
  )

  firewall_id                  = local.firewall_external ? var.firewall_id : hcloud_firewall.this[0].id
  current_ipv4_lookup_required = local.firewall_use_current_ipv4 || local.bare_metal_initialization_firewall_use_current_ipv4 || local.bare_metal_firewall_use_current_ipv4
  current_ipv6_lookup_required = local.firewall_use_current_ipv6 || local.bare_metal_initialization_firewall_use_current_ipv6 || local.bare_metal_firewall_use_current_ipv6
}

data "http" "current_ipv4" {
  count = local.current_ipv4_lookup_required ? 1 : 0
  url   = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }

  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "HTTP status code invalid"
    }
  }
}

data "http" "current_ipv6" {
  count = local.current_ipv6_lookup_required ? 1 : 0
  url   = "https://${local.current_ipv6_lookup_required ? "ipv6." : ""}icanhazip.com"

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 1000
  }

  lifecycle {
    postcondition {
      condition     = contains([200], self.status_code)
      error_message = "HTTP status code invalid"
    }
  }
}

resource "hcloud_firewall" "this" {
  count = local.firewall_external ? 0 : 1
  name  = var.cluster_name

  dynamic "rule" {
    for_each = local.firewall_rules_list
    //noinspection HILUnresolvedReference
    content {
      description     = rule.value.description
      direction       = rule.value.direction
      source_ips      = lookup(rule.value, "source_ips", [])
      destination_ips = lookup(rule.value, "destination_ips", [])
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
    }
  }

  labels = {
    cluster = var.cluster_name
  }
}

resource "terraform_data" "bare_metal_firewall" {
  for_each = local.bare_metal_enabled ? local.bare_metal_servers : {}

  triggers_replace = {
    server_number = each.value.number
    rules         = sha1(jsonencode(local.bare_metal_firewall_curl_data))
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Applying Robot firewall for bare metal server %s\n' "${each.value.number}"

      response_file=$(mktemp)
      curl_config=$(mktemp)
      cleanup() { rm -f "$response_file" "$curl_config"; }
      trap 'cleanup' EXIT

      printf '%s' "$ROBOT_FIREWALL_CURL_DATA" | jq -r '.[] | "data-urlencode = " + (. | @json)' > "$curl_config"

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          --config "$curl_config" \
          "${var.hcloud_robot_api_url}/firewall/${each.value.number}" || true)

        case "$status" in
          200|201|202)
            break
            ;;
          409)
            printf 'Robot firewall update for server %s is still in process, retrying (%s/100)\n' "${each.value.number}" "$attempt"
            sleep 10
            ;;
          *)
            printf 'Unexpected Robot API status while applying firewall for server %s: %s\n' "${each.value.number}" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      if [ "$status" != "200" ] && [ "$status" != "201" ] && [ "$status" != "202" ]; then
        printf 'Robot firewall update for server %s did not complete after retries, last status: %s\n' "${each.value.number}" "$status" >&2
        exit 1
      fi

      printf 'Waiting 60 seconds for Robot firewall update to apply on server %s\n' "${each.value.number}"
      sleep 60

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "${var.hcloud_robot_api_url}/firewall/${each.value.number}" || true)

        case "$status" in
          200)
            firewall_status=$(jq -r '.firewall.status // empty' "$response_file")

            case "$firewall_status" in
              active)
                break
                ;;
              "in process")
                printf 'Robot firewall for server %s is still in process, waiting (%s/100)\n' "${each.value.number}" "$attempt"
                sleep 10
                ;;
              *)
                printf 'Unexpected Robot firewall status for server %s: %s\n' "${each.value.number}" "$firewall_status" >&2
                exit 1
                ;;
            esac
            ;;
          *)
            printf 'Unexpected Robot API status while checking firewall for server %s: %s\n' "${each.value.number}" "$status" >&2
            exit 1
            ;;
        esac
      done

      if [ "$firewall_status" != "active" ]; then
        printf 'Robot firewall for server %s did not become active after retries, last status: %s\n' "${each.value.number}" "$firewall_status" >&2
        exit 1
      fi

      printf 'Robot firewall applied for bare metal server %s\n' "${each.value.number}"
    EOT

    environment = {
      ROBOT_FIREWALL_CURL_DATA = jsonencode(local.bare_metal_firewall_curl_data)
      ROBOT_USER               = var.hcloud_robot_user
      ROBOT_PASSWORD           = nonsensitive(var.hcloud_robot_password)
    }
  }

  depends_on = [
    terraform_data.bare_metal_server
  ]
}
