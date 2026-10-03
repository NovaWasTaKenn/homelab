# ── SDN — VXLAN zone ──────────────────────────────────────────────────────────
resource "proxmox_sdn_zone_vxlan" "homelab" {
  id    = "homelab"
  peers = var.node_ips   # list of node IPs for VXLAN peer mesh
  mtu   = 1450           # 1500 - 50 bytes VXLAN overhead
  nodes = var.nodes
}

# SDN applier — pushes zone config to all nodes before creating the vnet
resource "proxmox_sdn_applier" "after_zone" {
  depends_on = [proxmox_sdn_zone_vxlan.homelab]
}

# ── SDN — VNet ────────────────────────────────────────────────────────────────
resource "proxmox_sdn_vnet" "homelab" {
  id   = "vnetlab"
  zone = proxmox_sdn_zone_vxlan.homelab.id

  depends_on = [proxmox_sdn_applier.after_zone]
}

# SDN applier — pushes vnet config to all nodes after vnet creation
resource "proxmox_sdn_applier" "after_vnet" {
  depends_on = [proxmox_sdn_vnet.homelab]

  lifecycle {
    replace_triggered_by = [proxmox_sdn_vnet.homelab]
  }
}
