resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "this" {
  name       = var.cluster_name
  public_key = tls_private_key.ssh_key.public_key_openssh

  labels = {
    cluster = var.cluster_name
  }
}

resource "terraform_data" "robot_ssh_key" {
  count = var.hcloud_robot_user != null ? 1 : 0

  triggers_replace = {
    key_name       = var.cluster_name
    public_key     = tls_private_key.ssh_key.public_key_openssh
    fingerprint    = tls_private_key.ssh_key.public_key_fingerprint_md5
    robot_password = var.hcloud_robot_password
  }

  input = {
    robot_api_url = var.hcloud_robot_api_url
    robot_user    = var.hcloud_robot_user
    key_name      = var.cluster_name
    public_key    = tls_private_key.ssh_key.public_key_openssh
    fingerprint   = tls_private_key.ssh_key.public_key_fingerprint_md5
  }

  provisioner "local-exec" {
    quiet   = true
    command = <<-EOT
      set -eu

      status=$(curl -sS -o /dev/null -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        "${self.input.robot_api_url}/key/${self.input.fingerprint}" || true)

      case "$status" in
        200)
          exit 0
          ;;
        404)
          curl -sSf \
            -u "$ROBOT_USER:$ROBOT_PASSWORD" \
            --data-urlencode "name=${self.input.key_name}" \
            --data-urlencode "data=${self.input.public_key}" \
            "${self.input.robot_api_url}/key" >/dev/null
          ;;
        *)
          printf 'Unexpected Robot API status while checking SSH key %s: %s\n' "${self.input.fingerprint}" "$status" >&2
          exit 1
          ;;
      esac
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

      status=$(curl -sS -o /dev/null -w '%%{http_code}' \
        -u "$ROBOT_USER:$ROBOT_PASSWORD" \
        -X DELETE \
        "${self.input.robot_api_url}/key/${self.input.fingerprint}" || true)

      case "$status" in
        200|204|404)
          exit 0
          ;;
        *)
          printf 'Unexpected Robot API status while deleting SSH key %s: %s\n' "${self.input.fingerprint}" "$status" >&2
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
