terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_hostname}.${var.domain}"
  node_name = var.target_node

  on_boot = var.onboot


  agent {
    enabled = true
    timeout = "15m"
    trim = false
    type = "virtio"
  }

  tags = var.vm_tags

  cpu {
    type    = "x86-64-v2-AES"
    cores   = var.cores
    sockets = var.sockets
    flags   = []
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
  }

  network_device {
    bridge  = "vnetall"
    model   = "virtio"
    vlan_id = 100
  }
  
  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }

  boot_order    = ["scsi0"]
  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "scsi0"
    iothread     = true
    datastore_id = "${var.disk.storage}"
    size         = var.disk.size
    discard      = "ignore"
  }

  clone {
    vm_id = var.template_vm_id
  }

}

