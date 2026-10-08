# Configuration & Secrets

This document explains how shared configuration values and secrets are managed across the project.

---

## Environment Variables

All shared, non-secret configuration values live in `config.env` at the repository root. Examples include:

- `DOMAIN`, `PROXMOX_HOST`, `PROXMOX_PORT`
- `DNS_ADDRESS`, `ADMIN_HOST`, `NODE_PREFIX`
- `SSH_PUBLIC_KEY`, `SSH_IDENTITY_FILE`
- `PROJECT_PATH`

The Nix flake (`env/flake.nix`) sources `config.env` in its `shellHook`, so every development shell automatically exports these variables:

```nix
shellHook = ''
  set -a
  source '/home/quentin/Repos/homelab/config.env'
  set +a
'';
```

When using direnv, the flake loads automatically upon entering the project directory.

---

## Node Registry

`nodes.json` at the repository root is the source of truth for the cluster nodes' name → IP mapping. It is **written by the PXE infra** (each node records its IP when it fetches its installer answer file) and committed to git — do not edit it by hand.

Consumers:

- **Terraform** reads it in `main.tf` via `jsondecode(file("${var.project_path}/nodes.json"))` and derives `local.nodes` / `local.node_ips` from it.
- **Ansible** loads it in `register-nodes.yaml`, which populates the `proxmox` / `proxmox_bootstrap` inventory groups with `add_host` before any other play runs.

It is refreshed automatically on every node (re)install.

---

## Secrets

All secrets are stored in a single SOPS-encrypted file: `secrets.enc.yaml`. They are **never** written in plaintext anywhere in the repository.

### SOPS Encryption

- **Tool**: [Mozilla SOPS](https://github.com/getsops/sops) with Age keys.
- **File**: `secrets.enc.yaml` at the repository root.
- **Runtime access**: Secrets are decrypted at runtime by the tool that needs them.

### Ansible

Ansible loads secrets via the `community.sops.sops` lookup plugin inside the inventory or playbooks:

```yaml
sops: "{{ lookup('community.sops.sops', project_path + '/secrets.enc.yaml') | ansible.builtin.from_yaml }}"
```

Individual values are then referenced as `{{ sops.<key> }}`, for example:

```yaml
root_password: "{{ sops.proxmox_root_password }}"
```

Environment variables are read with `lookup('env', 'VAR_NAME')`.

### Terraform

Terraform uses the `carlpett/sops` provider to expose the encrypted file as a data source:

```hcl
data "sops_file" "secrets" {
  source_file = "${var.project_path}/secrets.enc.yaml"
}
```

Values are accessed as `data.sops_file.secrets.data["<key>"]`, for example:

```hcl
api_token = data.sops_file.secrets.data["proxmox_api_token"]
```

Terraform variables that need to come from the environment are prefixed with `TF_VAR_` in `config.env` so they are picked up automatically by Terraform.

### Molecule

Molecule tests run with environment variables sourced by the same `config.env` file. To pass secrets into a Molecule run, use `sops exec-env`:

```bash
sops exec-env secrets.enc.yaml 'molecule test'
```

`sops exec-env` exports secrets under the **raw key names** from `secrets.enc.yaml` (e.g., `proxmox_root_password`), not renamed variants.

