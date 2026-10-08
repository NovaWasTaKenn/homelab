run "one_off_lands_on_biggest_node" {
  command = plan

  variables {
    nodes_by_capacity = ["big", "medium", "small"]
    definitions = [
      { name = "vm-a" },
      { name = "vm-b" },
    ]
  }

  assert {
    condition     = output.instances["vm-a"].target_node == "big"
    error_message = "one-off vm-a should land on the biggest node"
  }

  assert {
    condition     = output.instances["vm-b"].target_node == "big"
    error_message = "one-off vm-b should land on the biggest node"
  }
}

run "replicas_spread_across_nodes" {
  command = plan

  variables {
    nodes_by_capacity = ["big", "medium", "small"]
    definitions = [
      { name = "ctrl", replicas = 3 },
    ]
  }

  assert {
    condition     = output.instances["ctrl-1"].target_node == "big" && output.instances["ctrl-2"].target_node == "medium" && output.instances["ctrl-3"].target_node == "small"
    error_message = "replicas should spread across nodes by descending capacity"
  }

  assert {
    condition     = length(output.instances) == 3
    error_message = "3 replicas should produce 3 instances"
  }
}

run "replicas_wrap_around_when_exceeding_node_count" {
  command = plan

  variables {
    nodes_by_capacity = ["big", "small"]
    definitions = [
      { name = "worker", replicas = 3 },
    ]
  }

  assert {
    condition     = output.instances["worker-3"].target_node == "big"
    error_message = "replica index beyond node count should wrap to the biggest node"
  }
}

run "pinned_node_bypasses_placement" {
  command = plan

  variables {
    nodes_by_capacity = ["big", "small"]
    definitions = [
      { name = "router", node = "small" },
    ]
  }

  assert {
    condition     = output.instances["router"].target_node == "small"
    error_message = "a definition with node set should be pinned to that node"
  }
}

run "extra_attributes_pass_through" {
  command = plan

  variables {
    nodes_by_capacity = ["big"]
    definitions = [
      { name = "vm-a", cores = 4, memory = 8192, tags = ["x"] },
    ]
  }

  assert {
    condition     = output.instances["vm-a"].cores == 4 && output.instances["vm-a"].tags == ["x"]
    error_message = "definition attributes should be passed through to the instance"
  }
}

run "empty_definitions_yield_empty_placement" {
  command = plan

  variables {
    nodes_by_capacity = ["big"]
    definitions       = []
  }

  assert {
    condition     = length(output.instances) == 0
    error_message = "no definitions should produce no instances"
  }
}
