# Syntax / env wiring bugs (transient)

These are plain bugs — expected to be fixed soon — not design decisions. Re-verify each before acting on it.

## Confirmed as of the current tree

1. **`vms/ansible/homelab.proxmox.yml:11`** — dynamic inventory loads the sops file with the wrong name and a missing `/`:
   ```
   sops: "{{ lookup('community.sops.sops', project_path + 'secrets.yaml') | ... }}"
   ```
   The file is `secrets.enc.yaml` (see `layer1/ansible/inventory.yaml` for the correct usage) and the concatenation yields `...homelabsecrets.yaml`, missing the `/`.

2. **`ansible_roles/create_pve_user/molecule/default/molecule.yml`** — references env vars that are not defined in `config.env`:
   - `api_token_secret: "${MOLECULE_PROXMOX_TOKEN_SECRET}"`
   - `playbook_password` / `root_password: "${PROXMOX_ROOT_PASSWORD}"`
   `config.env` defines `MOLECULE_PROXMOX_TOKEN_ID` but no `*_TOKEN_SECRET`; the root password lives in sops as `proxmox_root_password`. `sops exec-env` exports the raw sops keys, so these `${...}` names never resolve.

3. **`layer1/ansible/inventory.yaml`** — hardcoded nix-store python path under `proxmox` group vars:
   ```
   ansible_python_interpreter: /nix/store/l9k0anq0z7zz81zcwy035jfwap9ga6rl-python3-3.13.13/bin/python3
   ```
   The store path hash changes whenever flake inputs change — will break after `nix flake update`/gc. (The `proxmox_bootstrap` group correctly uses `/usr/bin/python3`.)

4. **`vms/terraform/main.tf:26`** — provider `ssh` block references an undeclared variable:
   ```
   provider "proxmox" {
     ...
     ssh {
       agent    = true
       username = var.proxmox_provide_user   # not in vms/terraform/vars.tf
     }
   }
   ```
   `vars.tf` declares `terraform_user`, not `proxmox_provide_user` — `terraform validate` fails.

5. **`admin_infra/http-files/boot.ipxe`** — typos: `promxox-img/` (and one `promox-img/`) everywhere in the `kernel`/`initrd` lines; the real dir is `proxmox-img`. The `auto` menu item works, but `gui`/`tui`/`serial`/`debug` items load nothing.

6. **`config.env`**:
   - `TF_VAR_ssh_public_key_path=${SSH_PUBLIC_KEY}` — sets the *path* var to the key *content*; terraform `data "local_file"` then tries to read a file named like the pubkey. (Local `*.auto.tfvars` also set `ssh_pkey_path`, which contradicts the terraform var name `ssh_public_key_path`.)
   - `ANSIBLE_SSH_PRIVATE_KEY_FILE=${SSH_PRIVATE_KEY_FILE}` — `SSH_PRIVATE_KEY_FILE` is never defined in `config.env`, so it resolves empty unless exported by the user's shell profile.

7. **Module path mix** — `TF_VAR_tf_modules_path` is declared (`config.env`) and `tf_modules_path` is a variable in `vms/terraform/vars.tf`, but no module `source` uses it: `vms/terraform/main.tf` mixes relative `../../terraform_modules/...` and absolute `~/Repos/homelab/terraform_modules/...`, and `layer1/terraform/main.tf` uses the absolute path.
