# Network Topology

This document describes the current network layout and future alternatives.

---

## Current State

### Physical / Home Network

```
Internet
   │
   ▼
ISP Router (192.168.1.0/24)
   │
   ├── Home devices (PCs, phones, admin workstation)
   │
   └── (Unmanaged switch if needed)
           │
           └── Proxmox nodes (bare-metal)
```

- The ISP router is the default gateway for the home LAN.
- Proxmox nodes have at least one physical interface on the home LAN (`vmbr0`).

### Virtual / Lab Network

Inside Proxmox, a **VXLAN-based SDN** provides an isolated overlay for lab workloads:

- **Zone**: `vxlan-homelab`
- **VNet**: `vnet-homelab`
- **MTU**: 1450 (1500 minus 50-byte VXLAN overhead)
- **Peers**: All Proxmox node IPs form a full-mesh VXLAN peer set.

### OPNsense Router VM

OPNsense runs as a VM on one of the Proxmox nodes. It bridges the two networks:

| NIC | Network | Role |
|-----|---------|------|
| `vtnet0` (or `eth0`) | Home LAN (`vmbr0`) | WAN / upstream |
| `vtnet1` (or `eth1`) | VXLAN (`vnet-homelab`) | LAN / internal lab DHCP + DNS |

Services provided to the VXLAN side:
- DHCP for VM / container workloads
- DNS resolution and local records
- Firewall / NAT between home LAN and lab network

---

## Future Options

Two possible evolutions for the network layer are being considered:

### 1. Hardware Homelab Network

Deploy a dedicated hardware router (or OPNsense on dedicated hardware) **before** the switch that feeds the Proxmox nodes.

**Pros:**
- Full control over DHCP, DNS, and firewall rules for the entire homelab segment
- Cleaner topology (router is a physical boundary)

**Cons:**
- Additional hardware cost
- Extra physical complexity (more cables, another box)

### 2. Virtual Homelab Network (Current Approach)

Keep OPNsense as a VM inside Proxmox.

**Pros:**
- No extra hardware
- Infrastructure is software-defined and can be managed via IaC (VM provisioning)
- Lower physical complexity

**Cons:**
- Less control over the physical-link DHCP (still handled by ISP router)
- Circular dependency: the router VM needs Proxmox to be up, but some services may depend on the router
- Slightly weirder topology (router lives inside the infrastructure it routes)

The current implementation follows option 2. The trade-offs are acceptable for a single-site homelab and can be abstracted via IaC.
