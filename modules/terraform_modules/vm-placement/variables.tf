variable "nodes_by_capacity" {
  description = "Proxmox node names sorted by capacity, biggest first"
  type        = list(string)

  validation {
    condition     = length(var.nodes_by_capacity) > 0
    error_message = "At least one node is required for placement."
  }
}

variable "definitions" {
  description = <<-EOT
    Workload definitions to place on nodes.
    Each definition must have a `name` and may set `replicas` (default 1) and
    `node` (pin to a specific node, bypassing placement).
    All other attributes are passed through untouched to the output.
  EOT
  type        = any

  validation {
    condition     = alltrue([for d in var.definitions : can(d.name)])
    error_message = "Every definition must have a name."
  }

  validation {
    condition     = alltrue([for d in var.definitions : lookup(d, "replicas", 1) >= 1])
    error_message = "replicas must be >= 1."
  }
}
