# ── OPNsense router VM (pinned — not auto-placed, router stability) ───────────
module "opnsense-vm" {
  source = "../../../modules/terraform_modules/opnsense-vm"

  template_vm_id     = 9997
  target_node        = "node-2"
  onboot             = true
  target_node_domain = var.domain
  vm_hostname        = "opnsense"
  domain             = var.domain
  vm_tags            = ["opnsense", "networking"]
  sockets            = 1
  cores              = 2
  memory             = 4096
  vm_user            = "root" # OPNsense uses root
  ssh_public_key     = data.local_file.ssh_public_key.content
  disk = {
    storage = "local-lvm"
    size    = 20
  }
}

# ── Auto-placed VMs ───────────────────────────────────────────────────────────
# Definitions live in proxmox.tfvars; node assignment is computed in
# placement.tf (one-offs on the biggest node, replicas spread).
module "vms" {
  source   = "../../../modules/terraform_modules/download-vm"
  for_each = module.vm_placement.instances

  ssh_public_key     = data.local_file.ssh_public_key.content
  download_url       = each.value.download_url
  checksum           = each.value.checksum
  target_node        = each.value.target_node
  onboot             = each.value.onboot
  target_node_domain = var.domain
  vm_hostname        = each.value.name
  domain             = var.domain
  vm_tags            = each.value.tags
  sockets            = each.value.sockets
  cores              = each.value.cores
  memory             = each.value.memory
  vm_user            = each.value.user
  disk               = each.value.disk
  additionnal_disks  = each.value.additionnal_disks
}

# ── Auto-placed containers ────────────────────────────────────────────────────
module "containers" {
  source   = "../../../modules/terraform_modules/download-container"
  for_each = module.ct_placement.instances

  ssh_public_key     = data.local_file.ssh_public_key.content
  img_url            = each.value.img_url
  network_interfaces = each.value.network_interfaces
  target_node        = each.value.target_node
  datastore_id       = each.value.datastore_id
  ct_user            = each.value.user
  ct_hostname        = each.value.name
  domain             = var.domain
  gateway_ip         = var.homelab_vnet_dns
  tags               = each.value.tags
}

# ── iSCSI shared storage container (placeholder — needs parameterisation) ─────
# module "iscsi-storage" {
#   source = "../../../modules/terraform_modules/download-container"
#
#   ssh_public_key = data.local_file.ssh_public_key.content
#   template_ct_id = 9998
#   target_node    = "node-3"
#   datastore_id   = "local-lvm"
#   ct_user        = "nova"
#   ct_hostname    = "shared-temp-store"
#   domain         = var.domain
#   img_url        = "https://cloud-images.ubuntu.com/releases/resolute/release-20260612/ubuntu-26.04-server-cloudimg-amd64-root.tar.xz"
#   if_name        = "vtnet0"
#   if_bridge      = "vmbr0"
#   gateway_ip     = var.dns_address
# }
