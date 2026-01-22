resource "hcloud_zone" "this" {
  count = var.dns_zone_create ? 1 : 0

  name = var.dns_zone_name
  mode = "primary"
}
