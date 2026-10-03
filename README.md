# Homelab

A fully Infrastructure-as-Code managed, close-to-production-grade homelab running on Proxmox VE with virtualized networking and a future Kubernetes layer.

This repository contains everything needed to provision, configure, and manage a bare-metal Proxmox cluster from a single admin workstation — from PXE booting fresh nodes to deploying virtual machines and network services.

---

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Virtualization | Proxmox VE | HA virtualization, SDN, shared storage |
| IaC (primary) | Terraform | Declarative VMs, containers, networking |
| IaC (imperative) | Ansible | Bootstrapping, clustering, one-off scripts |
| Secrets | SOPS + Age | Encrypted secrets, decrypted at runtime |
| Dev Environment | Nix + direnv | Reproducible tooling shell |
| Containers | Podman | PXE boot services, local workloads |
| PXE Boot | iPXE + dnsmasq | Unattended Proxmox node installation |

---

## Architecture

```
                    ☁️ Internet
                       │
                       ▼
              ┌─────────────────┐
               │  ISP Router     │
               │  192.168.1.0/24 │
              └────────┬────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
   ┌────▼─────┐              ┌────────▼────────┐
   │ Admin PC │              │ Proxmox Nodes   │
   │ (Nix ❄️) │◄─────────────┤ (Bare Metal)    │
   │          │  PXE / iPXE  │                 │
    │ ┌──────────────┐ │              │ ┌───┐ ┌───┐ ┌──┐│
    │ │TFTP + HTTP   │ │              │ │N1 │ │N2 │ │N3││
    │ │DNSmasq proxy │ │              │ └───┘ └───┘ └──┘│
   │ └──────┘ │              └────────┬────────┘
   └──────────┘                       │
                                      │
                         ┌────────────▼────────────┐
                         │   Proxmox VE Cluster    │
                         │                        │
                         │  ┌─────────────────┐  │
                         │  │  VXLAN SDN        │  │
                         │  │  vnet-homelab     │  │
                         │  └─────────────────┘  │
                         │                        │
                         │  ┌─────────────────┐  │
                         │  │ 🔥 OPNsense VM   │  │
                         │  │ Router / Firewall│  │
                         │  └─────────────────┘  │
                         │                        │
                         │  ┌─────────────────┐  │
                         │  │ ☸️ Kubernetes    │  │
                         │  │   (Future work)  │  │
                         │  └─────────────────┘  │
                         └────────────────────────┘
```

- **Proxmox VE** runs directly on bare-metal nodes and hosts all VMs and containers.
- **OPNsense** is a VM inside the cluster that routes between the home LAN and the internal VXLAN (`vnet-homelab`).
- **Kubernetes** is not yet deployed; the layer is planned for Helm charts + a GitOps operator.
- **Admin / PXE** services run on the admin workstation to bootstrap fresh nodes unattended.

See [`docs/architecture.md`](docs/architecture.md) for the full component breakdown and repository layout.

---

## Prerequisites

- **Hardware**: At least one Proxmox node (three or more for HA).
- **Software**:
  - [Nix](https://nixos.org/) with flakes enabled
  - [direnv](https://direnv.net/) (optional, for automatic shell loading)
  - An [Age](https://github.com/FiloSottile/age) key authorized for the SOPS file

---

## Quick Start — Bootstrap the Homelab

> **Note**: These steps reflect the current working state. A single-command deployment script will be added later.

### 1. Enter the development shell

```bash
direnv allow   # or: nix develop
```

This loads all tools (Terraform, Ansible, SOPS, Molecule, Podman, ...) and exports environment variables from `config.env`.

### 2. Start the PXE boot services

```bash
just setup-pxe-infra
```

This starts a local TFTP server (dnsmasq) and an HTTP answer server required for unattended Proxmox installation.

### 4. Boot the nodes

Power on each bare-metal node and select network boot (PXE / iPXE). The nodes will chain-load the Proxmox automated installer from the HTTP server.

### 5. Bootstrap the Proxmox cluster

Once the nodes are installed and reachable:

```bash
cd infra_components/proxmox/ansible

ansible-playbook -i inventory.yaml bootstrap-cluster.yaml
```

Secrets (root password, etc.) are loaded from the sops file via the inventory. For the first run, nodes may still use root password auth; subsequent runs use the ansible user with key-based auth.

This playbook sequence:
1. Hardens SSH and creates the `ansible` automation user (`bootstrap-nodes.yaml`)
2. Creates the Proxmox cluster and joins all nodes (`setup-cluster.yaml`)
3. Provisions the Terraform API user and token (`setup-terraform-pve-user.yaml`)

### 6. Apply Terraform

```bash
cd infra_components/proxmox/terraform

terraform init
terraform plan -out=homelab.tfplan
terraform apply homelab.tfplan
```

Terraform manages:
- Cluster options and APT repositories
- SDN / VXLAN zone and VNet
- VMs and containers (via reusable modules)
- Shared storage containers

### 7. Verify

- Proxmox Web UI: `https://<proxmox-host>:8006`
- OPNsense Web UI: deployed inside the cluster, reachable on its WAN IP
- Check cluster status on any node: `pvecm status`

---

## Development Environment

The project uses a Nix flake (`env/flake.nix`) to provide a reproducible shell with all required tools. The flake automatically sources `config.env` on entry, so all project variables are available immediately.

```bash
# If direnv is installed, the shell loads automatically when you cd into the repo
cd /path/to/homelab

# Otherwise, enter the flake manually
nix develop
```

---

## Configuration & Secrets

- **Non-secrets**: [`config.env`](config.env) at the repository root. Sourced automatically by the Nix shell hook.
- **Secrets**: [`secrets.enc.yaml`](secrets.enc.yaml), encrypted with SOPS + Age. Decrypted at runtime by Terraform (`carlpett/sops` provider) and Ansible (`community.sops.sops` lookup).

Ansible and Terraform read environment variables prefixed with `ANSIBLE_*` and `TF_VAR_*` respectively. Molecule tests run inside `sops exec-env` so secrets are injected as plain env vars.

See [`docs/config.md`](docs/config.md) for the full configuration guide.

---

## Repository Structure

```
.
├── env/                          # Nix flake (development shell)
├── config.env                    # Shared non-secret variables
├── secrets.enc.yaml              # SOPS-encrypted secrets
├── justfile                      # Common automation recipes
├── infra_components/
│   ├── admin_infra/              # PXE / TFTP / HTTP boot services
│   ├── proxmox/
│   │   ├── ansible/              # Bootstrap & cluster playbooks
│   │   └── terraform/            # VMs, SDN, cluster config
│   ├── opnsense/                 # Config backups & restore
│   ├── kubernetes_base/          # Placeholder — K8s core layer
│   └── kubernetes_apps/          # Placeholder — K8s app deployments
├── modules/
│   ├── terraform_modules/        # Reusable TF modules (VM, container, OPNsense)
│   └── ansible_roles/            # Reusable Ansible roles
├── docs/                         # Project documentation
└── apps/                         # Custom applications
```

> **Transition note**: `ansible_1` and `terraform_1` directories inside `infra_components/proxmox/` are temporary artifacts of an ongoing structure refactor and will be merged into their parent folders.

---

## Documentation

| Document | Contents |
|----------|----------|
| [`docs/architecture.md`](docs/architecture.md) | Component overview, repository layout |
| [`docs/iac.md`](docs/iac.md) | Terraform / Ansible philosophy, module catalog, PXE services |
| [`docs/network.md`](docs/network.md) | Network topology, VXLAN, OPNsense placement |
| [`docs/config.md`](docs/config.md) | Environment variables, SOPS, secrets workflow |
| [`docs/roadmap.md`](docs/roadmap.md) | Remaining tasks and future work |
| [`docs/syntax-bugs.md`](docs/syntax-bugs.md) | Transient bugs to fix during the refactor |

---

## Current Status & Roadmap

- ✅ Proxmox cluster bootstrapping (PXE → Ansible → Terraform)
- ✅ OPNsense VM deployment and backup workflow
- ✅ Reusable Terraform modules and Ansible roles
- 🔄 Repository structure refactor in progress (`ansible_1` / `terraform_1` merge)
- ⏳ Kubernetes layer — not yet started
- ⏳ One-command deployment script (`justfile` completion)

See [`docs/roadmap.md`](docs/roadmap.md) for the full task list.
