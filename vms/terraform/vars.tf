variable "proxmox_api_token" {
  description = "Token to connect Proxmox API"
  type = string
}

variable "template_tag" {
  description = "Tag of the vm's template"
  type = string
}

variable "ssh_public_key_path" {
  description = "Path to the ssh public key"
  type = string
}

variable "tf_modules_path" {
  description = "Path to the tf modules "
  type = string
}

variable "homelab_vnet_dns" {
  description = "The address of the dns server"
  type = string
}

variable "domain" {
  description = "VM domain"
  type        = string
}

variable "terraform_user" {
  description = "terraform user"
  type        = string
}

