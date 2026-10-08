# Workload definitions for the Proxmox layer.
# Passed explicitly: terraform plan|apply -var-file=proxmox.tfvars
# (or via the justfile terraform recipes).
#
# Placement is automatic (see placement.tf):
#   - one-offs (default) land on the biggest node
#   - replicas = N spreads N instances (<name>-1 .. <name>-N) across nodes
#   - node = "<node>" pins the workload, bypassing placement

vm_definitions = [
  {
    name         = "kube-node"
    replicas     = 2
    download_url = "https://cloud-images.ubuntu.com/releases/resolute/release-20260918/ubuntu-26.04-server-cloudimg-amd64.img"
    checksum     = "8800651811af9a85465ad1d552add729947bb16488dddb4a9b5305a3d97332b2"
    cores        = 1
    memory       = 2048
    tags         = ["ubuntu", "basic_vm"]
  },
]

ct_definitions = [
  {
    name         = "opnsense-backup"
    img_url      = "https://images.linuxcontainers.org/images/debian/bookworm/amd64/cloud/20260602_05:24/disk.qcow2"
    datastore_id = "shared-template"
    user         = "opnsense-backup"
    network_interfaces = [
      {
        name    = "eth0"
        bridge  = "vnetall"
        vlan_id = 100
      }
    ]
  },
]
