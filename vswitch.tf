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

      # The module detaches its own servers before this runs. Servers that are still attached were
      # attached by something else (or this resource is dropped because hcloud_vswitch_id is now
      # set), so the vSwitch is kept instead of cutting those servers off.
      status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${self.input.robot_api_url}/vswitch/$vswitch_id" || true)

      case "$status" in
        200)
          ;;
        404)
          exit 0
          ;;
        *)
          printf 'Unexpected Robot API status while reading vSwitch %s before cancelling it: %s\n' "$vswitch_id" "$status" >&2
          exit 1
          ;;
      esac

      attached_servers=$(jq -r '[.server[]? | (.server_number | tostring)] | join(", ")' "$response_file")

      if [ -n "$attached_servers" ]; then
        printf 'Keeping vSwitch %s: servers %s are still attached. Cancel it in Robot once it is no longer needed.\n' "$vswitch_id" "$attached_servers"
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

# One instance per bare metal server. The state records which servers this module attached, so
# only those are detached again. Servers attached to the vSwitch by anything else are left alone.
resource "terraform_data" "vswitch_server" {
  # The Robot user may be passed in as a sensitive value. Only whether it is set is used here.
  for_each = local.bare_metal_enabled && nonsensitive(var.hcloud_robot_user != null) ? {
    for server in local.bare_metal_servers : tostring(server.number) => server
  } : {}

  triggers_replace = {
    vswitch_id    = local.hcloud_vswitch_id
    server_number = each.key
  }

  # Not part of triggers_replace: new Robot credentials must not detach and re-attach the servers.
  input = {
    robot_api_url  = var.hcloud_robot_api_url
    robot_user     = var.hcloud_robot_user
    robot_password = var.hcloud_robot_password
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      vswitch_id="${self.triggers_replace.vswitch_id}"
      server_number="${self.triggers_replace.server_number}"
      vswitch_url="${self.input.robot_api_url}/vswitch/$vswitch_id"

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      # Prints the status of this server on the vSwitch, or "absent".
      server_status() {
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "$vswitch_url" || true)

        if [ "$status" != "200" ]; then
          printf 'Unexpected Robot API status while reading vSwitch %s: %s\n' "$vswitch_id" "$status" >&2
          cat "$response_file" >&2
          return 1
        fi

        jq -r --arg server_number "$server_number" '
          [.server[]? | select((.server_number | tostring) == $server_number) | .status] |
          if length == 0 then "absent" else .[0] end
        ' "$response_file"
      }

      attachment_status=$(server_status)

      if [ "$attachment_status" = "absent" ]; then
        printf 'Attaching bare metal server %s to vSwitch %s\n' "$server_number" "$vswitch_id"

        for attempt in $(seq 1 100); do
          status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
            -u "$ROBOT_USER:$ROBOT_PASSWORD" \
            --data-urlencode "server[]=$server_number" \
            "$vswitch_url/server" || true)

          case "$status" in
            200|201|202|204)
              break
              ;;
            409)
              printf 'vSwitch %s is busy, retrying to attach server %s (%s/100)\n' "$vswitch_id" "$server_number" "$attempt"
              sleep 10
              ;;
            *)
              printf 'Unexpected Robot API status while attaching bare metal server %s to vSwitch %s: %s\n' "$server_number" "$vswitch_id" "$status" >&2
              cat "$response_file" >&2
              exit 1
              ;;
          esac
        done

        case "$status" in
          200|201|202|204) ;;
          *)
            printf 'Attaching bare metal server %s to vSwitch %s did not complete after retries, last status: %s\n' "$server_number" "$vswitch_id" "$status" >&2
            exit 1
            ;;
        esac
      fi

      for attempt in $(seq 1 100); do
        attachment_status=$(server_status)

        case "$attachment_status" in
          ready)
            printf 'Bare metal server %s is attached to vSwitch %s\n' "$server_number" "$vswitch_id"
            exit 0
            ;;
          failed)
            printf 'vSwitch %s attachment failed for server %s\n' "$vswitch_id" "$server_number" >&2
            exit 1
            ;;
          *)
            printf 'vSwitch %s attachment of server %s is not ready yet (%s), waiting (%s/100)\n' "$vswitch_id" "$server_number" "$attachment_status" "$attempt"
            sleep 10
            ;;
        esac
      done

      printf 'vSwitch %s attachment of server %s did not become ready after retries, last status: %s\n' "$vswitch_id" "$server_number" "$attachment_status" >&2
      exit 1
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.input.robot_password)
    }
  }

  provisioner "local-exec" {
    when    = destroy
    quiet   = true
    command = <<-EOT
      set -eu

      vswitch_id="${self.triggers_replace.vswitch_id}"
      server_number="${self.triggers_replace.server_number}"
      vswitch_url="${self.input.robot_api_url}/vswitch/$vswitch_id"

      response_file=$(mktemp)
      cleanup() { rm -f "$response_file"; }
      trap 'cleanup' EXIT
      trap 'exit 1' HUP INT TERM QUIT PIPE

      # Prints the status of this server on the vSwitch, or "absent" (also when the vSwitch is gone).
      server_status() {
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          "$vswitch_url" || true)

        case "$status" in
          200) ;;
          404)
            printf 'absent'
            return 0
            ;;
          *)
            printf 'Unexpected Robot API status while reading vSwitch %s: %s\n' "$vswitch_id" "$status" >&2
            cat "$response_file" >&2
            return 1
            ;;
        esac

        jq -r --arg server_number "$server_number" '
          if .cancelled == true then "absent" else
            [.server[]? | select((.server_number | tostring) == $server_number) | .status] |
            if length == 0 then "absent" else .[0] end
          end
        ' "$response_file"
      }

      attachment_status=$(server_status)

      if [ "$attachment_status" = "absent" ]; then
        printf 'Bare metal server %s is not attached to vSwitch %s\n' "$server_number" "$vswitch_id"
        exit 0
      fi

      printf 'Detaching bare metal server %s from vSwitch %s\n' "$server_number" "$vswitch_id"

      for attempt in $(seq 1 100); do
        status=$(curl -sS -o "$response_file" -w '%%{http_code}' \
          -u "$ROBOT_USER:$ROBOT_PASSWORD" \
          -X DELETE \
          --data-urlencode "server[]=$server_number" \
          "$vswitch_url/server" || true)

        case "$status" in
          200|202|204|404)
            break
            ;;
          409)
            printf 'vSwitch %s is busy, retrying to detach server %s (%s/100)\n' "$vswitch_id" "$server_number" "$attempt"
            sleep 10
            ;;
          *)
            printf 'Unexpected Robot API status while detaching bare metal server %s from vSwitch %s: %s\n' "$server_number" "$vswitch_id" "$status" >&2
            cat "$response_file" >&2
            exit 1
            ;;
        esac
      done

      case "$status" in
        200|202|204|404) ;;
        *)
          printf 'Detaching bare metal server %s from vSwitch %s did not complete after retries, last status: %s\n' "$server_number" "$vswitch_id" "$status" >&2
          exit 1
          ;;
      esac

      for attempt in $(seq 1 100); do
        attachment_status=$(server_status)

        case "$attachment_status" in
          absent)
            printf 'Bare metal server %s detached from vSwitch %s\n' "$server_number" "$vswitch_id"
            exit 0
            ;;
          failed)
            printf 'vSwitch %s detachment failed for server %s\n' "$vswitch_id" "$server_number" >&2
            exit 1
            ;;
          *)
            printf 'vSwitch %s detachment of server %s is not done yet (%s), waiting (%s/100)\n' "$vswitch_id" "$server_number" "$attachment_status" "$attempt"
            sleep 10
            ;;
        esac
      done

      printf 'vSwitch %s detachment of server %s did not complete after retries, last status: %s\n' "$vswitch_id" "$server_number" "$attachment_status" >&2
      exit 1
    EOT

    environment = {
      ROBOT_USER     = self.input.robot_user
      ROBOT_PASSWORD = nonsensitive(self.input.robot_password)
    }
  }

  depends_on = [data.external.vswitch]
}

# Replaced by terraform_data.vswitch_server. Forget the old instance instead of destroying it, so the
# upgrade plan shows no destroy. The old resource never called the Robot API on destroy.
removed {
  from = terraform_data.vswitch_attachment

  lifecycle {
    destroy = false
  }
}
