# ── Provider ──────────────────────────────────────────────────────────────────
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.104.0"
    }
    sops = {
      source = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

provider "sops" {}

data "sops_file" "secrets" {
  source_file = "${var.project_path}/secrets.yaml"
}

provider "proxmox" {
  endpoint  = var.proxmox_api
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  insecure  = true   # set to false if you have a valid TLS cert on Proxmox
}

data "local_file" "ssh_public_key" {
  filename = var.ssh_public_key_path
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
  source = "~/Repos/homelab/terraform_modules/download-container"
  ssh_public_key = data.local_file.ssh_public_key.content
  template_ct_id = 9998
  target_node = "node1"
  datastore_id = "local-lvm"
  ct_user = "nova"
  ct_hostname = "shared-temp-store"
  domain = var.domain
  img_url = "https://cloud-images.ubuntu.com/releases/resolute/release-20260612/ubuntu-26.04-server-cloudimg-amd64-root.tar.xz"
  if_name = "vtnet0"
  if_bridge = "vmbr0"
  gateway_ip = var.dns_address
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

