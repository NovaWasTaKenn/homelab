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

variable "template_tag" {
  description = "Tag of the vm's template"
  type        = string
}

variable "terraform_user" {
  description = "Terraform SSH user for Proxmox provider"
  type        = string
}

variable "terraform_token_id" {
  description = "Terraform token id"
  type        = string
}


# ── Workload definitions ──────────────────────────────────────────────────────
# Consumed by placement.tf. No defaults on purpose: running terraform without
# -var-file must fail loudly rather than plan an empty for_each (which would
# destroy every VM/container).
#
# Common optional fields:
#   replicas = N   -> spreads N instances across nodes, biggest first
#                     (default 1 = one-off, always lands on the biggest node)
#   node     = "x" -> pins the workload to a node, bypassing placement

variable "vm_definitions" {
  description = "VM definitions, auto-placed on nodes by descending capacity"
  type = list(object({
    name         = string
    replicas     = optional(number, 1)
    node         = optional(string)
    download_url = string
    checksum     = string
    onboot       = optional(bool, true)
    tags         = optional(list(string), ["ubuntu", "basic_vm"])
    sockets      = optional(number, 1)
    cores        = optional(number, 1)
    memory       = optional(number, 2048)
    user         = optional(string, "sysadmin")
    disk = optional(object({
      storage = string
      size    = number
      }), {
      storage = "local-lvm"
      size    = 10
    })
    additionnal_disks = optional(list(object({
      storage = string
      size    = number
    })), [])
  }))
}

variable "ct_definitions" {
  description = "Container definitions, auto-placed on nodes by descending capacity"
  type = list(object({
    name         = string
    replicas     = optional(number, 1)
    node         = optional(string)
    img_url      = string
    datastore_id = optional(string, "local-lvm")
    user         = string
    tags         = optional(list(string), [])
    network_interfaces = list(object({
      name    = string
      bridge  = string
      model   = optional(string, "virtio")
      vlan_id = optional(number, 0)
    }))
  }))
}
