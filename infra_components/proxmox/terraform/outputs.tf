# ── Placement visibility ──────────────────────────────────────────────────────
# Shown at the end of every plan/apply and via `terraform output`.

output "nodes_ranked" {
  description = "Cluster nodes ranked by descending capacity (cpu_count) — the list placement assigns from"
  value       = local.nodes_ranked
}

output "vm_placements" {
  description = "VM instance name => assigned node"
  value       = { for k, v in module.vm_placement.instances : k => v.target_node }
}

output "ct_placements" {
  description = "Container instance name => assigned node"
  value       = { for k, v in module.ct_placement.instances : k => v.target_node }
}
