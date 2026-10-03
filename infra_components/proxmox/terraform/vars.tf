variable "project_path" {
  description = "The path to the project's root"
  type        = string
}

variable "proxmox_api" {
  description = "The proxmox api url"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the ssh public key file"
  type        = string
}

variable "keyboard_layout" {
  description = "The keyboard layout for the vm"
  type        = string
}

variable "language" {
  description = "The language for the vms"
  type        = string
}

variable "dns_address" {
  description = "The address of the dns server"
  type        = string
}

variable "domain" {
  description = "VM domain"
  type        = string
}

variable "homelab_vnet_dns" {
  description = "The address of the vnet dns server"
  type        = string
}

variable "nodes" {
  description = "The nodes list"
  type        = list(string)
}

variable "node_ips" {
  description = "List of the node ips"
  type        = list(string)
}

variable "template_tag" {
  description = "Tag of the vm's template"
  type        = string
}

variable "terraform_user" {
  description = "Terraform SSH user for Proxmox provider"
  type        = string
}
