resource "terraform_data" "vswitch" {
  count = local.bare_metal_enabled && var.hcloud_robot_user != null && var.hcloud_vswitch_id == null ? 1 : 0

  triggers_replace = {
    name           = var.cluster_name
    vlan           = var.hcloud_vswitch_vlan_id
    robot_password = var.hcloud_robot_password
  }

  input = {
    robot_api_url = var.hcloud_robot_api_url
    robot_user    = var.hcloud_robot_user
    name          = var.cluster_name
    vlan          = var.hcloud_vswitch_vlan_id
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${self.input.robot_api_url}/vswitch" || true)

      case "$status" in
        200)
          ;;
        404)
          printf '[]' > "$response_file"
          ;;
        *)
          printf 'Unexpected Robot API status while listing vSwitches: %s\n' "$status" >&2
          exit 1
          ;;
      esac

      vswitch_id=$(
        jq -r --arg name "${self.input.name}" --argjson vlan "${self.input.vlan}" '
            map(select(.name == $name and .vlan == $vlan and .cancelled == false)) |
            if length == 0 then ""
            elif length == 1 then .[0].id
            else error("multiple matching vSwitches found")
            end
          ' "$response_file"
      )

      if [ -n "$vswitch_id" ]; then
        exit 0
      fi

      curl -sSf \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        --data-urlencode "name=${self.input.name}" \
        --data-urlencode "vlan=${self.input.vlan}" \
        "${self.input.robot_api_url}/vswitch" >/dev/null
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.triggers_replace.robot_password)
    }
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<-EOT
      set -eu

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${self.input.robot_api_url}/vswitch" || true)

      case "$status" in
        200)
          ;;
        404)
          printf '[]' > "$response_file"
          ;;
        *)
          printf 'Unexpected Robot API status while listing vSwitches: %s\n' "$status" >&2
          exit 1
          ;;
      esac

      vswitch_id=$(
        jq -r --arg name "${self.input.name}" --argjson vlan "${self.input.vlan}" '
            map(select(.name == $name and .vlan == $vlan and .cancelled == false)) |
            if length == 0 then ""
            elif length == 1 then .[0].id
            else error("multiple matching vSwitches found")
            end
          ' "$response_file"
      )

      if [ -z "$vswitch_id" ]; then
        exit 0
      fi

      status=$(curl -sS -o /dev/null -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        -X DELETE \
        --data-urlencode "cancellation_date=now" \
        "${self.input.robot_api_url}/vswitch/$vswitch_id" || true)

      case "$status" in
        200|204|404|409)
          exit 0
          ;;
        *)
          printf 'Unexpected Robot API status while deleting vSwitch %s: %s\n' "$vswitch_id" "$status" >&2
          exit 1
          ;;
      esac
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.triggers_replace.robot_password)
    }
  }
}

data "external" "vswitch" {
  count = local.bare_metal_enabled && var.hcloud_robot_user != null ? 1 : 0

  depends_on = [terraform_data.vswitch]

  program = [
    "sh", "-c", <<-EOT
      set -eu

      input=$(cat)
      robot_api_url=$(printf '%s' "$input" | jq -r '.robot_api_url')
      robot_user=$(printf '%s' "$input" | jq -r '.robot_user')
      robot_password=$(printf '%s' "$input" | jq -r '.robot_password')
      id=$(printf '%s' "$input" | jq -r '.id')
      name=$(printf '%s' "$input" | jq -r '.name')
      vlan=$(printf '%s' "$input" | jq -r '.vlan')

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$robot_user:$robot_password" \
        "$robot_api_url/vswitch" || true)

      case "$status" in
        200)
          ;;
        404)
          printf '[]' > "$response_file"
          ;;
        *)
          printf 'Unexpected Robot API status while looking up vSwitch: %s\n' "$status" >&2
          exit 1
          ;;
      esac

      if [ "$id" != "null" ]; then
        vswitch=$(
          jq -r --arg id "$id" '
            map(select((.id | tostring) == $id and .cancelled == false)) |
            if length == 1 then .[0]
            elif length == 0 then error("vSwitch not found")
            else error("multiple matching vSwitches found")
            end
          ' "$response_file"
        )
      else
        vswitch=$(
          jq -r --arg name "$name" --argjson vlan "$vlan" '
              map(select(.name == $name and .vlan == $vlan and .cancelled == false)) |
              if length == 1 then .[0]
              elif length == 0 then error("vSwitch not found")
              else error("multiple matching vSwitches found")
              end
            ' "$response_file"
        )
      fi

      printf '%s' "$vswitch" | jq '{id: (.id | tostring), vlan: (.vlan | tostring)}'
    EOT
  ]

  query = {
    robot_api_url  = var.hcloud_robot_api_url
    robot_user     = var.hcloud_robot_user
    robot_password = var.hcloud_robot_password
    id             = var.hcloud_vswitch_id != null ? tostring(var.hcloud_vswitch_id) : null
    name           = var.cluster_name
    vlan           = var.hcloud_vswitch_vlan_id != null ? tostring(var.hcloud_vswitch_vlan_id) : null
  }
}

locals {
  hcloud_vswitch_id = var.hcloud_vswitch_id != null ? var.hcloud_vswitch_id : (
    local.bare_metal_enabled && var.hcloud_robot_user != null ? tonumber(nonsensitive(data.external.vswitch[0].result.id)) : null
  )
  hcloud_vswitch_vlan_id = local.bare_metal_enabled && var.hcloud_robot_user != null ? tonumber(nonsensitive(data.external.vswitch[0].result.vlan)) : var.hcloud_vswitch_vlan_id
}

resource "terraform_data" "vswitch_attachment" {
  count = local.bare_metal_enabled && var.hcloud_robot_user != null ? 1 : 0

  triggers_replace = {
    vswitch_id     = local.hcloud_vswitch_id
    server_numbers = sort([for server in local.bare_metal_servers : tostring(server.number)])
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Checking vSwitch %s for bare metal servers to attach\n' "${self.triggers_replace.vswitch_id}"

      response_file=$(mktemp)
      curl_config=$(mktemp)
      cleanup() { rm -f "$response_file" "$curl_config"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}" || true)

      case "$status" in
        200)
          ;;
        *)
          printf 'Unexpected Robot API status while checking vSwitch %s server attachments: %s\n' "${self.triggers_replace.vswitch_id}" "$status" >&2
          cat "$response_file" >&2
          exit 1
          ;;
      esac

      server_numbers_to_attach=$(jq -c --argjson server_numbers "$SERVER_NUMBERS" '
        [$server_numbers[] as $server_number | select(([.server[]? | (.server_number | tostring)] | index($server_number) | not)) | $server_number]
      ' "$response_file")
      server_numbers_to_attach_label=$(printf '%s' "$server_numbers_to_attach" | jq -r 'join(", ")')

      if [ "$server_numbers_to_attach" = "[]" ]; then
        printf 'No bare metal servers to attach to vSwitch %s\n' "${self.triggers_replace.vswitch_id}"
      else
        printf 'Attaching bare metal servers %s to vSwitch %s\n' "$server_numbers_to_attach_label" "${self.triggers_replace.vswitch_id}"

        printf '%s' "$server_numbers_to_attach" | jq -r '.[] | "data-urlencode = \"server[]=" + . + "\""' > "$curl_config"

        for attempt in $(seq 1 100); do
          status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
            -u "$ROBOT_USER:$ROBOT_PASSWORD" \
            --config "$curl_config" \
            "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}/server" || true)

          case "$status" in
            200|201|202|204)
              break
              ;;
            409)
              printf 'vSwitch %s server attachment for servers %s is still in process, retrying (%s/100)\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_attach_label" "$attempt"
              sleep 10
              ;;
            *)
              printf 'Unexpected Robot API status while attaching bare metal servers %s to vSwitch %s: %s\n' "$server_numbers_to_attach_label" "${self.triggers_replace.vswitch_id}" "$status" >&2
              cat "$response_file" >&2
              exit 1
              ;;
          esac
        done

        if [ "$status" != "200" ] && [ "$status" != "201" ] && [ "$status" != "202" ] && [ "$status" != "204" ]; then
          printf 'Attaching bare metal servers %s to vSwitch %s did not complete after retries, last status: %s\n' "$server_numbers_to_attach_label" "${self.triggers_replace.vswitch_id}" "$status" >&2
          exit 1
        fi

        printf 'Waiting 60 seconds for vSwitch %s server attachment to apply\n' "${self.triggers_replace.vswitch_id}"
        sleep 60
      fi

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}" || true)

        case "$status" in
          200)
            attachment_status=$(jq -r --argjson server_numbers "$SERVER_NUMBERS" '
              [.server[]? | select((.server_number | tostring) as $server_number | $server_numbers | index($server_number)) | .status] as $statuses |
              if ($statuses | length) != ($server_numbers | length) then "missing"
              elif any($statuses[]; . == "failed") then "failed"
              elif all($statuses[]; . == "ready") then "ready"
              else "in process"
              end
            ' "$response_file")

            case "$attachment_status" in
              ready)
                break
                ;;
              "in process"|missing)
                printf 'vSwitch %s server attachment for servers %s is not ready yet (%s), waiting (%s/100)\n' "${self.triggers_replace.vswitch_id}" "$SERVER_NUMBERS_LABEL" "$attachment_status" "$attempt"
                sleep 10
                ;;
              failed)
                printf 'vSwitch %s server attachment failed for servers %s\n' "${self.triggers_replace.vswitch_id}" "$SERVER_NUMBERS_LABEL" >&2
                exit 1
                ;;
              *)
                printf 'Unexpected vSwitch %s server attachment status for servers %s: %s\n' "${self.triggers_replace.vswitch_id}" "$SERVER_NUMBERS_LABEL" "$attachment_status" >&2
                exit 1
                ;;
            esac
            ;;
          *)
            printf 'Unexpected Robot API status while checking vSwitch %s server attachment for servers %s: %s\n' "${self.triggers_replace.vswitch_id}" "$SERVER_NUMBERS_LABEL" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      if [ "$attachment_status" != "ready" ]; then
        printf 'vSwitch %s server attachment for servers %s did not become ready after retries, last status: %s\n' "${self.triggers_replace.vswitch_id}" "$SERVER_NUMBERS_LABEL" "$attachment_status" >&2
        exit 1
      fi

      printf 'Bare metal servers %s attached to vSwitch %s\n' "$SERVER_NUMBERS_LABEL" "${self.triggers_replace.vswitch_id}"
    EOT

    environment = {
      ROBOT_USER           = var.hcloud_robot_user
      ROBOT_PASSWORD       = nonsensitive(var.hcloud_robot_password)
      SERVER_NUMBERS       = jsonencode(self.triggers_replace.server_numbers)
      SERVER_NUMBERS_LABEL = join(", ", self.triggers_replace.server_numbers)
    }
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      printf 'Checking vSwitch %s for bare metal servers to detach\n' "${self.triggers_replace.vswitch_id}"

      response_file=$(mktemp)
      curl_config=$(mktemp)
      cleanup() { rm -f "$response_file" "$curl_config"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}" || true)

      case "$status" in
        200)
          ;;
        *)
          printf 'Unexpected Robot API status while checking vSwitch %s server attachments: %s\n' "${self.triggers_replace.vswitch_id}" "$status" >&2
          cat "$response_file" >&2
          exit 1
          ;;
      esac

      server_numbers_to_detach=$(jq -c --argjson server_numbers "$SERVER_NUMBERS" '
        [.server[]? | (.server_number | tostring) as $server_number | select(($server_numbers | index($server_number) | not)) | $server_number]
      ' "$response_file")
      server_numbers_to_detach_label=$(printf '%s' "$server_numbers_to_detach" | jq -r 'join(", ")')

      if [ "$server_numbers_to_detach" = "[]" ]; then
        printf 'No bare metal servers to detach from vSwitch %s\n' "${self.triggers_replace.vswitch_id}"
        exit 0
      fi

      printf 'Detaching bare metal servers %s from vSwitch %s\n' "$server_numbers_to_detach_label" "${self.triggers_replace.vswitch_id}"

      printf '%s' "$server_numbers_to_detach" | jq -r '.[] | "data-urlencode = \"server[]=" + . + "\""' > "$curl_config"

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          -X DELETE \
          --config "$curl_config" \
          "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}/server" || true)

        case "$status" in
          200|202|204)
            break
            ;;
          409)
            printf 'vSwitch %s server cleanup for servers %s is still in process, retrying (%s/100)\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" "$attempt"
            sleep 10
            ;;
          *)
            printf 'Unexpected Robot API status while detaching bare metal servers %s from vSwitch %s: %s\n' "$server_numbers_to_detach_label" "${self.triggers_replace.vswitch_id}" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      if [ "$status" != "200" ] && [ "$status" != "202" ] && [ "$status" != "204" ]; then
        printf 'Detaching bare metal servers %s from vSwitch %s did not complete after retries, last status: %s\n' "$server_numbers_to_detach_label" "${self.triggers_replace.vswitch_id}" "$status" >&2
        exit 1
      fi

      printf 'Waiting 60 seconds for vSwitch %s server cleanup to apply\n' "${self.triggers_replace.vswitch_id}"
      sleep 60

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "${var.hcloud_robot_api_url}/vswitch/${self.triggers_replace.vswitch_id}" || true)

        case "$status" in
          200)
            cleanup_status=$(jq -r --argjson server_numbers_to_detach "$server_numbers_to_detach" '
              [.server[]? | select((.server_number | tostring) as $server_number | ($server_numbers_to_detach | index($server_number))) | .status] as $statuses |
              if ($statuses | length) == 0 then "removed"
              elif any($statuses[]; . == "failed") then "failed"
              else "in process"
              end
            ' "$response_file")

            case "$cleanup_status" in
              removed)
                break
                ;;
              "in process")
                printf 'vSwitch %s server cleanup for servers %s is not done yet, waiting (%s/100)\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" "$attempt"
                sleep 10
                ;;
              failed)
                printf 'vSwitch %s server cleanup failed for servers %s\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" >&2
                exit 1
                ;;
              *)
                printf 'Unexpected vSwitch %s server cleanup status for servers %s: %s\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" "$cleanup_status" >&2
                exit 1
                ;;
            esac
            ;;
          *)
            printf 'Unexpected Robot API status while checking vSwitch %s server cleanup for servers %s: %s\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      if [ "$cleanup_status" != "removed" ]; then
        printf 'vSwitch %s server cleanup for servers %s did not complete after retries, last status: %s\n' "${self.triggers_replace.vswitch_id}" "$server_numbers_to_detach_label" "$cleanup_status" >&2
        exit 1
      fi

      printf 'Bare metal servers %s detached from vSwitch %s\n' "$server_numbers_to_detach_label" "${self.triggers_replace.vswitch_id}"
    EOT

    environment = {
      ROBOT_USER     = var.hcloud_robot_user
      ROBOT_PASSWORD = nonsensitive(var.hcloud_robot_password)
      SERVER_NUMBERS = jsonencode(self.triggers_replace.server_numbers)
    }
  }

  depends_on = [data.external.vswitch]
}
