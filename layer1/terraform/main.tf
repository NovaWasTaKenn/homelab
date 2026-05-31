# ── Provider ──────────────────────────────────────────────────────────────────
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true   # set to false if you have a valid TLS cert on Proxmox
}

# ── Cluster options ───────────────────────────────────────────────────────────
resource "proxmox_cluster_options" "options" {
  keyboard = var.keyboard_layout
  language = var.language
}

# ── APT repositories (per node) ───────────────────────────────────────────────
# Enable no-subscription repo and disable enterprise repo on every node.
# Uses for_each over the node list so it scales to any number of nodes.

resource "proxmox_apt_standard_repository" "no_subscription" {
  for_each  = toset(var.nodes)
  node_name = each.key
  handle    = "no-subscription"
}

# --- Create iscsi storage container -------------------------------------------

module "iscsi-storage" {
  source = "~/Repos/homelab/terraform_modules/template-container"
  ssh_public_key = data.local_file.ssh_public_key.content
  template_ct_id = 9998
  target_node = "node1"
  datastore_id = "local-lvm"
  ct_user = "nova"
  ct_hostname = "shared-temp-store"
  domain = "pve.local"
}

# ── SDN — VXLAN zone ──────────────────────────────────────────────────────────
resource "proxmox_sdn_zone_vxlan" "homelab" {
  id    = "vxlan-homelab"
  peers = var.node_ips   # list of node IPs for VXLAN peer mesh
  mtu   = 1450           # 1500 - 50 bytes VXLAN overhead
  nodes = var.nodes
}

# SDN applier — pushes zone config to all nodes before creating the vnet
resource "proxmox_sdn_applier" "after_zone" {
  depends_on = [proxmox_virtual_environment_sdn_zone_vxlan.homelab]
}

# ── SDN — VNet ────────────────────────────────────────────────────────────────
resource "proxmox_sdn_vnet" "homelab" {
  id   = "vnet-homelab"
  zone = proxmox_virtual_environment_sdn_zone_vxlan.homelab.id

  depends_on = [proxmox_virtual_environment_sdn_applier.after_zone]
}

# SDN applier — pushes vnet config to all nodes after vnet creation
resource "proxmox_sdn_applier" "after_vnet" {
  depends_on = [proxmox_virtual_environment_sdn_vnet.homelab]

  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_sdn_vnet.homelab]
  }
}

