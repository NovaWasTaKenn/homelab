terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

resource "proxmox_virtual_environment_file" "cloud_user_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data = templatefile("../cloud-init/user_data.yaml", 
  {
        vm_hostname     = var.ct_hostname
        domain = var.domain
        ssh_public_key = var.ssh_public_key
        vm_user = var.ct_user
      }
)

    file_name = "${var.ct_hostname}.${var.domain}-ci-user.yml"
  }
}

resource "proxmox_virtual_environment_file" "cloud_meta_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.target_node

  source_raw {
    data = file("../cloud-init/meta_data.yaml")

    file_name = "${var.ct_hostname}.${var.domain}-ci-meta_data.yml"
  }
}

resource "proxmox_virtual_environment_container" "iscsi_target" {
  node_name   = var.target_node
  description = "iSCSI target for shared template storage (temporary)"
  tags        = ["iscsi", "storage", "temporary"]

  started  = true
  unprivileged = true

  cpu {
    cores = 1
  }

  memory {
    dedicated = 512
    swap      = 256
  }

  disk {
    datastore_id = var.datastore_id
    size         = 20        # 20GB — template storage only
  }

  network_interface {
  name     = "eth0"
  bridge   = "vmbr0"      # reachable by all nodes for iSCSI
  firewall = false
}

clone {
  datastore_id = var.datastore_id
  vm_id = var.template_ct_id
}
  
  initialization {
    hostname = var.ct_hostname

    ip_config {
ipv4 {
      address = "192.168.1.203/24"
      gateway = "192.168.1.254"
    }
    }
    
  }
}
