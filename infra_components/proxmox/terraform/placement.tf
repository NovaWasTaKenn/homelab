# ── Node ranking & workload placement ─────────────────────────────────────────
# Ranks cluster nodes by static capacity (logical CPU count) and hands the
# ranked list to the placement module, which assigns every VM/container
# instance a node (see modules/terraform_modules/vm-placement).
#
# NOTE: ranking deliberately uses cpu_count only. memory_available / online
# from the same data source fluctuate at runtime; ranking on them would
# reshuffle placement between applies, and changing a VM's node forces its
# recreation.

data "proxmox_virtual_environment_nodes" "all" {}

locals {
  # Zero-padded "cpu:name" strings give a stable descending sort (ties broken
  # by node name for determinism).
  nodes_ranked = [
    for s in reverse(sort([
      for i, name in data.proxmox_virtual_environment_nodes.all.names :
      format("%010d:%s", data.proxmox_virtual_environment_nodes.all.cpu_count[i], name)
    ])) : split(":", s)[1]
  ]
}

module "vm_placement" {
  source = "../../../modules/terraform_modules/vm-placement"

  nodes_by_capacity = local.nodes_ranked
  definitions       = var.vm_definitions
}

module "ct_placement" {
  source = "../../../modules/terraform_modules/vm-placement"

  nodes_by_capacity = local.nodes_ranked
  definitions       = var.ct_definitions
}
