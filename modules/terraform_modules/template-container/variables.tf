variable "target_node" {
  description = "Proxmox node to deploy the iSCSI LXC on"
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for the LXC disk (e.g. local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "template_ct_id" {
  description = "Id of the template container"
  type        = string
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
  sensitive   = true
}
