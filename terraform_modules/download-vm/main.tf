terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

resource "proxmox_download_file" "vm-image" {
  content_type       = "iso"
  datastore_id       = "local"
  file_name          = "vm-image.iso"
  node_name          = var.target_node
  url                = var.download_url
  checksum           = var.checksum
  checksum_algorithm = "sha256"
  decompression_algorithm = "bz2"
  overwrite = false
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_hostname}.${var.domain}"
  node_name = var.target_node

  on_boot = var.onboot
  timeout_create = 120
  started        = true
  reboot         = false

  agent {
    enabled = false
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
    file_id   = proxmox_download_file.vm-image.id
    datastore_id = "${var.disk.storage}"
    size         = var.disk.size
    discard      = "ignore"
  }

  dynamic "disk" {
    for_each = var.additionnal_disks
    content {
      interface    = "scsi${1 + disk.key}"
      iothread     = true
      datastore_id = "${disk.value.storage}"
      size         = disk.value.size
      discard      = "ignore"
      file_format  = "raw"
    }
  }


  initialization {
    # ip_config {
    #   ipv4 {
    #     address = "dhcp"
    #   }
    # }

    datastore_id         = "local-lvm"
    interface            = "ide2"
  }


}

