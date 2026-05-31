terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.201:8006/"
  api_token = var.api_token
  insecure = true
  ssh {
    agent    = true
    username = "root"
  }
}

data "local_file" "ssh_public_key" {
  filename = var.ssh_pkey_path
}



module "opnsense-vm" {
  source = "~/Repos/homelab/terraform_modules/opnsense-vm"
  template_vm_id     = 9997              # your template VM ID
  target_node        = "node1"
  onboot             = true
  target_node_domain = "pve.local"
  vm_hostname        = "opnsense"
  domain             = "pve.local"
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

module "vm1" {
  source = "~/Repos/homelab/terraform_modules/template-vm"
  ssh_public_key = data.local_file.ssh_public_key.content
  template_vm_id = 9999
  target_node = "node1"
  onboot = true
  target_node_domain = "pve.local"
  vm_hostname = "vm1"
  domain = "pve.local"
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



