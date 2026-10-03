# ── OPNsense router VM ─────────────────────────────────────────────────────────
module "opnsense-vm" {
  source = "../../../modules/terraform_modules/opnsense-vm"

  template_vm_id     = 9997
  target_node        = "node-3"
  onboot             = true
  target_node_domain = var.domain
  vm_hostname        = "opnsense"
  domain             = var.domain
  vm_tags            = ["opnsense", "networking"]
  sockets            = 1
  cores              = 2
  memory             = 4096
  vm_user            = "root"            # OPNsense uses root
  ssh_public_key     = data.local_file.ssh_public_key.content
  disk = {
    storage = "local-lvm"
    size    = 20
  }
}

# ── OPNsense backup container ────────────────────────────────────────────────
module "opnsense-backup-container" {
  source = "../../../modules/terraform_modules/download-container"

  ssh_public_key = data.local_file.ssh_public_key.content
  img_url        = "https://images.linuxcontainers.org/images/debian/bookworm/amd64/cloud/20260602_05:24/disk.qcow2"
  network_interfaces = [
    {
      name    = "eth0"
      bridge  = "vnetall"
      vlan_id = 100
      model   = "virtio"
    }
  ]
  target_node  = "node-3"
  datastore_id = "shared-template"
  ct_user      = "opnsense-backup"
  ct_hostname  = "opnsense-backup"
  domain       = var.domain
  gateway_ip   = var.homelab_vnet_dns
}

# ── General-purpose template VM ────────────────────────────────────────────────
module "vm1" {
  source = "../../../modules/terraform_modules/template-vm"

  ssh_public_key     = data.local_file.ssh_public_key.content
  template_vm_id     = 9999
  target_node        = "node-3"
  onboot             = true
  target_node_domain = var.domain
  vm_hostname        = "vm1"
  domain             = var.domain
  vm_tags            = ["ubuntu", "basic_vm"]
  sockets            = 1
  cores              = 1
  memory             = 2048
  vm_user            = "sysadmin"
  disk = {
    storage = "local-lvm"
    size    = 10
  }
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
