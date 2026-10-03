# ── Provider ──────────────────────────────────────────────────────────────────
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.104.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.4.1"
    }
  }
}

provider "sops" {}

data "sops_file" "secrets" {
  source_file = "${var.project_path}/secrets.enc.yaml"
}

provider "proxmox" {
  endpoint  = var.proxmox_api
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  insecure  = true   # set to false if you have a valid TLS cert on Proxmox
  ssh {
    agent    = true
    username = var.terraform_user
  }
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
  for_each = toset(var.nodes)
  node     = each.key
  handle   = "no-subscription"
}
