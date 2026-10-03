# Architecture

This document describes the high-level architecture of the homelab and how the repository is organized.

---

## Components

### Proxmox VE

The foundational virtualization layer running directly on the hardware. It hosts:
- Kubernetes node VMs
- The OPNsense virtual router
- SDN / VXLAN overlay for the internal lab network
- Shared storage (iSCSI) and local ZFS pools

### OPNsense

A virtualized firewall and router deployed as a VM inside the Proxmox cluster. It bridges the home network and the Proxmox VXLAN, providing DNS, DHCP, and firewall services to the lab infrastructure.

### Kubernetes

Container orchestration layer for all homelab services. It abstracts the underlying infrastructure (Proxmox, networking) through a standardized API.

The Kubernetes layer is currently a **placeholder / future work**. The directories `infra_components/kubernetes_base` and `infra_components/kubernetes_apps` will eventually hold Helm charts or GitOps manifests (e.g., Flux or ArgoCD).

### Admin / PXE Infrastructure

A set of containerized services (TFTP + HTTP) that provide unattended Proxmox installation. It runs on the admin workstation via `podman compose` and is used to bootstrap bare-metal nodes before they join the cluster.

---

## Repository Layout

| Path | Purpose |
|------|---------|
| `env/` | Nix flake defining the development shell and tooling |
| `config.env` | Shared configuration values (IPs, keys, project paths) |
| `secrets.enc.yaml` | SOPS-encrypted secrets, decrypted at runtime |
| `infra_components/admin_infra/` | PXE boot services (iPXE, TFTP, HTTP answer server) |
| `infra_components/proxmox/` | All Proxmox-related IaC **(target merged state)** |
| `infra_components/proxmox/terraform/` | Terraform configuration for VMs, containers, SDN, cluster options |
| `infra_components/proxmox/ansible/` | Ansible playbooks for bootstrapping, clustering, user provisioning |
| `infra_components/opnsense/` | OPNsense configuration backups and restore playbooks |
| `infra_components/kubernetes_base/` | **Placeholder** — base cluster configuration (CNI, storage, monitoring) |
| `infra_components/kubernetes_apps/` | **Placeholder** — application deployments (Helm/GitOps) |
| `modules/terraform_modules/` | Reusable Terraform modules (VMs, containers, OPNsense VM) |
| `modules/ansible_roles/` | Reusable Ansible roles (PVE user creation, backup jobs) |
| `docs/` | Project documentation |
| `justfile` | Automation recipes for common operations |

> **Note on directory names**: `ansible_1` and `terraform_1` inside `infra_components/proxmox/` are transitional artifacts from an ongoing structure refactor. They will be merged into their parent `ansible/` and `terraform/` directories. All documentation describes the **target merged layout**.
