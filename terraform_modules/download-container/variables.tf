variable "target_node" {
  description = "Proxmox node to deploy the iSCSI LXC on"
  type        = string
}

variable "img_url" {
  description = "The url of the container's image"
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for the LXC disk (e.g. local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_key" {
  description = "SSH public key for root access"
  type        = string
}

variable "ct_user" {
  description = "User for the container"
  type        = string
  sensitive   = true
}

variable "ct_hostname" {
  description = "Hostname of the container"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Domain of the container"
  type        = string
}

variable "if_name" {
  description = "The interface name"
  type        = string
}

variable "if_bridge" {
  description = "The interface bridge"
  type        = string
}

variable "gateway_ip" {
  description = "The gateway's ip"
  type        = string
}
