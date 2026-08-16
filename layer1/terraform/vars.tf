variable "project_path" {
  description = "The path to the project's root"
  type = string
}

variable "ssh_public_key_path" {
  description = "The ssh public key"
  type = string
}

variable "proxmox_api" {
  description = "The proxmox api url"
  type = string
}

variable "proxmox_api_token" {
  description = "the Proxmox api token"
  type = string
}

variable "keyboard_layout" {
  description = "The keyboard layout for the vm"
  type = string
}

variable "language" {
  description = "The language for the vms"
  type = string
}

variable "dns_address" {
  description = "The address of the dns server"
  type = string
}

variable "domain" {
  description = "VM domain"
  type        = string
}

variable "nodes" {
  description = "The nodes list"
  type        = list
}

variable "nodes_ips" {
  description = "List of the nodes ips"
  type        = list
}

