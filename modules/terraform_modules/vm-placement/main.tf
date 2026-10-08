# ── Workload placement ────────────────────────────────────────────────────────
# Assigns each workload instance a Proxmox node from a capacity-ranked list.
#
# Algorithm (simple ranking):
#   - each definition expands into `replicas` instances
#   - one-offs (replicas = 1) keep their name and land on the biggest node
#   - replicas are named "<name>-<i>" and replica i lands on the i-th biggest
#     node (wrapping around if replicas > node count)
#   - a definition with `node` set is pinned to that node instead
#
# The module is pure logic (no resources) so the algorithm can later be swapped
# for bin-packing without changing its callers.

locals {
  instances = {
    for pair in flatten([
      for d in var.definitions : [
        for i in range(lookup(d, "replicas", 1)) : {
          key = lookup(d, "replicas", 1) > 1 ? "${d.name}-${i + 1}" : d.name
          instance = merge(d, {
            name = lookup(d, "replicas", 1) > 1 ? "${d.name}-${i + 1}" : d.name
            target_node = lookup(d, "node", null) != null ? d.node : (
              var.nodes_by_capacity[i % length(var.nodes_by_capacity)]
            )
          })
        }
      ]
    ]) : pair.key => pair.instance
  }
}
