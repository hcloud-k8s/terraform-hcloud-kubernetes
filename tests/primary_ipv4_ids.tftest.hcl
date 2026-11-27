# Plan-only tests with mocked providers: no Hetzner resources are created.
#
#   terraform init -backend=false
#   terraform test

mock_provider "hcloud" {}
mock_provider "talos" {}
mock_provider "helm" {}
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "192.0.2.1"
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "external" {}

variables {
  cluster_name = "test"
  hcloud_token = "0123456789012345678901234567890123456789012345678901234567890123"

  control_plane_nodepools = [
    { name = "control", type = "cpx22", location = "nbg1", count = 3 }
  ]
}

# Without the variable the servers keep the default behaviour: Hetzner creates
# the Primary IPs automatically. For nodes without an ID the planned ipv4 is
# unknown (computed by Hetzner), so these runs only check that the plan is valid.
run "no_primary_ipv4_ids_keeps_default_behavior" {
  command = plan

  variables {
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 2 }
    ]
  }

  assert {
    condition     = length(hcloud_server.worker) == 2 && length(hcloud_server.control_plane) == 3
    error_message = "The plan must be unchanged when primary_ipv4_ids is not set."
  }
}

# An explicitly empty list is the same as omitting it.
run "empty_primary_ipv4_ids_keeps_default_behavior" {
  command = plan

  variables {
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 2, primary_ipv4_ids = [] }
    ]
  }

  assert {
    condition     = length(hcloud_server.worker) == 2
    error_message = "An empty primary_ipv4_ids must behave like an unset one."
  }
}

# IDs are attached in order; nodes beyond the list length keep the default.
run "worker_primary_ipv4_ids_are_attached_in_order" {
  command = plan

  variables {
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 3, primary_ipv4_ids = [101, 102] },
      { name = "other", type = "cpx22", location = "nbg1", count = 1 }
    ]
  }

  assert {
    condition     = one(hcloud_server.worker["test-apps-1"].public_net).ipv4 == 101
    error_message = "The first node of the pool must get the first Primary IPv4 ID."
  }

  assert {
    condition     = one(hcloud_server.worker["test-apps-2"].public_net).ipv4 == 102
    error_message = "The second node of the pool must get the second Primary IPv4 ID."
  }

  assert {
    condition     = length(hcloud_server.worker) == 4
    error_message = "Nodes beyond the list length and pools without primary_ipv4_ids must still be created."
  }
}

run "control_plane_primary_ipv4_ids_are_attached_in_order" {
  command = plan

  variables {
    control_plane_nodepools = [
      { name = "control", type = "cpx22", location = "nbg1", count = 3, primary_ipv4_ids = [201, 202, 203] }
    ]
  }

  assert {
    condition = alltrue([
      one(hcloud_server.control_plane["test-control-1"].public_net).ipv4 == 201,
      one(hcloud_server.control_plane["test-control-2"].public_net).ipv4 == 202,
      one(hcloud_server.control_plane["test-control-3"].public_net).ipv4 == 203,
    ])
    error_message = "Control Plane nodes must get the Primary IPv4 IDs in order."
  }
}

run "worker_primary_ipv4_ids_longer_than_count_is_rejected" {
  command = plan

  variables {
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 2, primary_ipv4_ids = [101, 102, 103] }
    ]
  }

  expect_failures = [var.worker_nodepools]
}

run "control_plane_primary_ipv4_ids_longer_than_count_is_rejected" {
  command = plan

  variables {
    control_plane_nodepools = [
      { name = "control", type = "cpx22", location = "nbg1", count = 1, primary_ipv4_ids = [201, 202] }
    ]
  }

  expect_failures = [var.control_plane_nodepools]
}

run "duplicate_primary_ipv4_ids_are_rejected" {
  command = plan

  variables {
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 2, primary_ipv4_ids = [101, 101] }
    ]
  }

  expect_failures = [var.worker_nodepools]
}

run "primary_ipv4_ids_require_public_ipv4" {
  command = plan

  variables {
    talos_public_ipv4_enabled = false
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 1, primary_ipv4_ids = [101] }
    ]
  }

  expect_failures = [var.worker_nodepools]
}

run "primary_ipv4_id_used_in_two_nodepools_is_rejected" {
  command = plan

  variables {
    control_plane_nodepools = [
      { name = "control", type = "cpx22", location = "nbg1", count = 3, primary_ipv4_ids = [201] }
    ]
    worker_nodepools = [
      { name = "apps", type = "cpx22", location = "nbg1", count = 1, primary_ipv4_ids = [201] }
    ]
  }

  expect_failures = [var.worker_nodepools]
}

run "control_plane_duplicate_primary_ipv4_ids_are_rejected" {
  command = plan

  variables {
    control_plane_nodepools = [
      { name = "control", type = "cpx22", location = "nbg1", count = 3, primary_ipv4_ids = [201, 201] }
    ]
  }

  expect_failures = [var.control_plane_nodepools]
}

run "control_plane_primary_ipv4_ids_require_public_ipv4" {
  command = plan

  variables {
    talos_public_ipv4_enabled = false
    control_plane_nodepools = [
      { name = "control", type = "cpx22", location = "nbg1", count = 3, primary_ipv4_ids = [201] }
    ]
  }

  expect_failures = [var.control_plane_nodepools]
}
