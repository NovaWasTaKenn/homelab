variable "api_token" {
  description = "Token to connect Proxmox API"
  type = string
}

variable "template_tag" {
  description = "Tag of the vm's template"
  type = string
}

variable "ssh_pkey_path" {
  description = "Path to the ssh public key"
  type = string
}

variable "tf_modules_path" {
  description = "Path to the ssh public key"
  type = string
}
