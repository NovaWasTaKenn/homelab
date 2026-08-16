terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
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
  ssh {
    agent    = true
    username = var.proxmox_provide_user
  }
}

data "local_file" "ssh_public_key" {
  filename = var.ssh_public_key_path
}

module "opnsense-vm" {
  source = "../../terraform_modules/opnsense-vm"
  template_vm_id     = 9997              # your template VM ID
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

module "opnsense-bakcup-container" {
  source = "~/Repos/homelab/terraform_modules/download-container"
  ssh_public_key = data.local_file.ssh_public_key.content
  img_url = "https://images.linuxcontainers.org/images/debian/bookworm/amd64/cloud/20260602_05:24/disk.qcow2" 
  network_interfaces = [
    {
      name ="eth0"
      bridge = "vnetall"
      vlan_id = 100
      model = "virtio"
    }
  ]
  target_node = "node-3"
  datastore_id = "shared-template"
  ct_user = "opnsense-backup"
  ct_hostname = "opnsense-backup"
  domain = var.domain
  gateway_ip = var.homelab_vnet_dns
}

module "vm1" {
  source = "../../terraform_modules/template-vm"
  ssh_public_key = data.local_file.ssh_public_key.content
  template_vm_id = 9999
  target_node = "node-3"
  onboot = true
  target_node_domain = var.domain
  vm_hostname = "vm1"
  domain = var.domain
  vm_tags = ["ubuntu", "basic_vm"]
  sockets = 1
  cores = 1
  memory =  2048
  vm_user = "sysadmin"
  disk = {
    storage = "local-lvm"
    size = 10
  }
}

# module "vm2" {
#   source = "~/Repos/homelab/terraform_modules/template-vm"
#
#
#   ssh_public_key = data.local_file.ssh_public_key.content
#   template_vm_id = 9998
#   target_node = "node2"
#   onboot = true
#   target_node_domain = "pve.local"
#   vm_hostname = "vm2"
#   domain = "pve.local"
#   vm_tags = ["ubuntu", "basic_vm"]
#   sockets = 1
#   cores = 1
#   memory =  2048
#   vm_user = "sysadmin"
#   disk = {
#     storage = "local-lvm"
#     size = 10
#   }
#
#
# }



