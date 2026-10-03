# Infrastructure as Code

This document describes how each infrastructure component is managed and which tools are used.

---

## Philosophy

- **Terraform** is the primary IaC tool. It owns all declarative, long-lived infrastructure (VMs, containers, SDN, cluster options).
- **Ansible** fills gaps and handles imperative or one-off operations (node bootstrapping, cluster creation, SSH hardening, user provisioning).
- All configuration values that are not secrets live in `config.env`.
- All secrets live in `secrets.enc.yaml` and are decrypted at runtime (see [config.md](config.md)).

---

## Proxmox VE

### Terraform (`infra_components/proxmox/terraform/`)

Manages:
- Provider and API token authentication (`insecure = true`, token auth via SOPS)
- Cluster options (keyboard layout, language)
- APT repositories (no-subscription, per node)
- SDN / VXLAN zone and VNet (`vxlan-homelab`, `vnet-homelab`)
- VMs and containers via reusable modules (see [Module Catalog](#module-catalog))
- Shared storage containers (e.g., iSCSI metadata container)

State is local and gitignored. Plans and state files are stored in the same directory.

### Ansible (`infra_components/proxmox/ansible/`)

Playbooks (target merged layout):

| Playbook | Purpose |
|----------|---------|
| `bootstrap-nodes.yaml` | Initial node hardening: creates `ansible` user, deploys SSH key, disables root login and password auth, hardens `sshd_config` |
| `setup-cluster.yaml` | Creates the Proxmox cluster from the first inventory node and joins remaining nodes sequentially |
| `setup-terraform-pve-user.yaml` | Creates a dedicated `terraform-prov@pve` user with a scoped role and API token for Terraform |
| `setup-iscsi-shared-storage.yaml` | *(Currently commented out)* Configures iSCSI shared storage across nodes |
| `bootstrap-cluster.yaml` | Meta-playbook that imports `bootstrap-nodes`, `setup-cluster`, and `setup-terraform-pve-user` |

Inventory groups:
- `proxmox_bootstrap` — nodes that need the initial bootstrap (fresh install).
- `proxmox` — all clustered nodes managed after bootstrap.

Dynamic inventory (`homelab.proxmox.yml`) uses the `community.proxmox.proxmox` plugin to discover VMs and tag-based groups at runtime.

---

## OPNsense

OPNsense is **not** well integrated with Terraform or Ansible. The workflow is:

1. **Terraform** deploys the OPNsense VM (via the `opnsense-vm` module).
2. **Manual configuration** is done through the OPNsense web UI.
3. **Periodic backup**: An Ansible role (`configure_opnsense_backup_job`) installs a cron job on the VM that generates an XML config backup and pushes it to this repository.
4. **Disaster recovery**: The `restore-opnsense.yml` playbook restores OPNsense from the latest XML backup.

---

## Admin / PXE Infrastructure

Located in `infra_components/admin_infra/`. Provides unattended Proxmox installation for bare-metal nodes.

Services (defined in `compose.yml`):

| Service | Role |
|---------|------|
| `dnsmasq` (TFTP) | Serves the iPXE EFI binary (`ipxe.efi`) to PXE clients |
| `dnsmasq` (DHCP) | DHCP proxy — intercepts DHCP requests and injects boot file paths (options 66/67) so the ISP router does not need to support them |
| `http` (custom Go server) | Serves static install files (kernel, initrd, ISO) and a dynamic answer file endpoint (`POST /answer`) |

Dnsmasq is configured as a DHCP Proxy, the ISP router doesnt need PXE specific configuration.

Boot files (`boot.ipxe`) chain-load the Proxmox automated installer from the HTTP server.

`just update-pxe-iso` downloads the latest Proxmox VE ISO, prepares it with `proxmox-auto-install-assistant` (answer fetched from `http://$PXE_HTTP_ADMIN_HOST/answer`), installs the ISO + `vmlinuz` + `initrd.img` into `http-files/proxmox-img/`, and updates the ISO reference in `boot.ipxe`.

---

## Kubernetes

The Kubernetes layer is **future work**. The intended approach is:
- **Base**: `infra_components/kubernetes_base/` — CNI, CSI, core operators, monitoring stack.
- **Apps**: `infra_components/kubernetes_apps/` — application deployments via Helm charts or a GitOps pull-based CD tool (Flux or ArgoCD).

No code currently exists in these directories.

---

## Module Catalog

### Terraform Modules (`modules/terraform_modules/`)

| Module | Purpose |
|--------|---------|
| `template-vm` | Clones a Proxmox VM template, configures cloud-init (user, SSH key, network), and sets compute / disk resources |
| `template-container` | Clones an LXC container template, configures user, network, and resources |
| `download-vm` | Downloads a cloud image, creates a new VM from it, and applies cloud-init |
| `download-container` | Downloads a rootfs tarball, creates a new LXC container, and applies network / user config |
| `opnsense-vm` | Specialized wrapper around `template-vm` for deploying OPNsense with appropriate disk and network defaults |

### Ansible Roles (`modules/ansible_roles/`)

| Role | Purpose |
|------|---------|
| `create_pve_user` | Creates a Proxmox VE user, role, and API token with scoped privileges. Used by `setup-terraform-pve-user.yaml` |
| `configure_opnsense_backup_job` | Installs a cron-based backup script and SSH deploy key on the OPNsense VM to periodically export and push the XML config |

Both roles include Molecule scenarios for testing against a live Proxmox instance.
