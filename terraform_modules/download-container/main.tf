terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.104.0"
    }
  }
}

resource "proxmox_virtual_environment_download_file" "container_image" {
  content_type = "vztmpl"
  datastore_id = var.datastore_id
  node_name    = var.target_node
  url          = var.img_url
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

resource "proxmox_virtual_environment_container" "container" {
  node_name   = var.target_node
  description = "Container"
  tags        = var.tags

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

  dynamic "network_interface" {

    for_each = var.network_interfaces
    content {
      name     = network_interface.name
      bridge   = network_interface.bridge
      model = network_interface.bridge
      firewall = false
      vlan_id = network_interface.vlan_id
    }
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.container_image.id
    # Or you can use a volume ID, as obtained from a "pvesm list <storage>"
    # template_file_id = "local:vztmpl/jammy-server-cloudimg-amd64.tar.gz"
    type             = "ubuntu"
  }
  
  initialization {
    hostname = var.ct_hostname

    ip_config {
ipv4 {
      address = "dhcp"
      gateway = var.gateway_ip
    }
    }
    
  }
}
