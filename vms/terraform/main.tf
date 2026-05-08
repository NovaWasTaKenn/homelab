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

data "proxmox_virtual_environment_vms" "template" {
  node_name = "node1"
  tags      = ["template", var.template_tag]
}


module "vm1" {
  source = "./basic-ubuntu-vm"
  ssh_public_key = data.local_file.ssh_public_key.content
  template_vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
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
    storage = "local_lvm"
    size = 10
  }
}

module "vm2" {
  source = "./basic-ubuntu-vm"

  ssh_public_key = data.local_file.ssh_public_key.content
  template_vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
  target_node = "node2"
  onboot = true
  target_node_domain = "pve.local"
  vm_hostname = "vm2"
  domain = "pve.local"
  vm_tags = ["ubuntu", "basic_vm"]
  sockets = 1
  cores = 1
  memory =  2048
  vm_user = "sysadmin"
  disk = {
    storage = "local_lvm"
    size = 10
  }


}
