resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "hcloud_ssh_key" "this" {
  name       = "${var.cluster_name}-default"
  public_key = trimspace(tls_private_key.ssh_key.public_key_openssh)

  labels = {
    cluster = var.cluster_name
  }
}
