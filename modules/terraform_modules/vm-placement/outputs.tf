output "instances" {
  description = "Map of instance key => definition augmented with `name` and `target_node`"
  value       = local.instances
}
