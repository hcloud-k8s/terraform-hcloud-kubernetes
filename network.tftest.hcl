# Asserts local.hcloud_network_zone from network.tf against expected zones.
# Targets only hcloud_network + subnet; mocks hcloud so no real API token is required.

mock_provider "hcloud" {}

variables {
  hcloud_token = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  cluster_name = "tftest-network"

  control_plane_nodepools = []
  agent_nodepools         = []
  autoscaler_nodepools    = []

  load_balancer_type     = "lb11"
  load_balancer_location = "fsn1"
  default_storage_class  = "longhorn"

  addons = {
    gateway_api               = { enabled = false }
    traefik                   = { enabled = false }
    cert_manager              = { enabled = false }
    local_path                = { enabled = false }
    longhorn                  = { enabled = false }
    hetzner_csi_driver        = { enabled = false }
    etcd_backup               = { enabled = false }
    metrics_server            = { enabled = false }
    cluster_autoscaler        = { enabled = false }
    hetzner_ccm               = { enabled = false }
    system_upgrade_controller = { enabled = false }
  }
}

run "weighted_winner_by_sum_of_count_different_locations" {
  command = plan

  plan_options {
    target = [
      hcloud_network_subnet.control_plane,
    ]
  }

  variables {
    control_plane_nodepools = [
      { name = "cp-fsn", type = "cx22", location = "fsn1", count = 2 },
      { name = "cp-nbg", type = "cx22", location = "nbg1", count = 2 },
      { name = "cp-sin", type = "cx22", location = "sin", count = 3 },
    ]
  }

  assert {
    condition     = local.hcloud_network_zone == "eu-central"
    error_message = "fsn1+nbg1 (6) beats sin (5) -> eu-central"
  }
}

run "weighted_winner_by_sum_of_count" {
  command = plan

  plan_options {
    target = [
      hcloud_network_subnet.control_plane,
    ]
  }

  variables {
    control_plane_nodepools = [
      { name = "cp-fsn", type = "cx22", location = "fsn1", count = 2 },
      { name = "cp-nbg", type = "cx22", location = "nbg1", count = 2 },
      { name = "cp-sin", type = "cx22", location = "sin", count = 5 },
    ]
  }

  assert {
    condition     = local.hcloud_network_zone == "ap-southeast"
    error_message = "sin count (5) beats fsn1 (2) and nbg1 (2) -> ap-southeast"
  }
}

run "ash_prefix_maps_us_east" {
  command = plan

  plan_options {
    target = [
      hcloud_network_subnet.control_plane,
    ]
  }

  variables {
    control_plane_nodepools = [
      { name = "cp-ash", type = "cx22", location = "ash", count = 1 },
    ]
  }

  assert {
    condition     = local.hcloud_network_zone == "us-east"
    error_message = "location prefix ash -> us-east"
  }
}

run "hil_prefix_maps_us_west" {
  command = plan

  plan_options {
    target = [
      hcloud_network_subnet.control_plane,
    ]
  }

  variables {
    control_plane_nodepools = [
      { name = "cp-hil", type = "cx22", location = "hil", count = 1 },
    ]
  }

  assert {
    condition     = local.hcloud_network_zone == "us-west"
    error_message = "location prefix hil -> us-west"
  }
}

run "sin_prefix_maps_ap_southeast" {
  command = plan

  plan_options {
    target = [
      hcloud_network_subnet.control_plane,
    ]
  }

  variables {
    control_plane_nodepools = [
      { name = "cp-sin", type = "cx22", location = "sin", count = 1 },
    ]
  }

  assert {
    condition     = local.hcloud_network_zone == "ap-southeast"
    error_message = "location prefix sin -> ap-southeast"
  }
}
