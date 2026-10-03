# AGENTS.md

Homelab IaC repo: a homelab managed via IAC using a kubernetes cluster hosted on a proxmox VE cluster

## Project intent
This project's goal is to provide a fully IAC managed, close to production grade homelab. 
The goals are :
    - Be able to setup the homelab in as few steps as possible
    - Secure
    - high availability

## Stack 
- Proxmox: Acts as the first layer over hardware mainly as a powerful HA virtualization layer to host the kube nodes vms
- Kubernetes: Container orchestration, host the apps and handles some supporting features storage, networking, ...
- Terraform: Primary way to manage the infrastructure
- Ansible: Secondary way to manage the infra. Used to fill terraform's gaps or for uses closer to one off scripts than infra description
- sops: Manages the projects secrets. Secrets only live in the encrypted sops file and are decrypted at runtime.
- Go: Coding language used for server or script needs

## Structure
- docs/: The documentation of the project
- env/: The nix flake used to setup the dev environment
- modules/: The directory containing the reusable terraform_modules and ansible_roles
- infra_components/: Contains the code describing/setting up the infrastructure of the homelabs components
- apps/: Contains the custom apps (code and other files) tied to the management or the setup of the homelab
- agents/: A folder containing any ai agent specific files 
- config.env: Regroups shared config options (ips, keys, project paths, ...). Options that arent shared go into specific config
- secrets.enc.yaml: Sops encoded secrets file.
- justfile: Contains recipes/scripts needed to manage the homelab

## Procedures
- Update the documentation as the project changes. Be only as verbose as the documentation already is. An architecture level doc doenst need syntax or command.
- Reference relevant new documentation in the agents.md
- Tests: Looks at each technology documentation for details as the method may differ 

## Rules
- Keep to the scope of the user's demand. Always prefer reporting any issues to the user instead of acting on them right away.
- Only touch the additional documentation section of the agents.md.It needs to stay concise, most documentation lives outside of it and referenced in additional documentation
- No hardcoded or clear-text secrets. Secrets live encrypted in the sops file secrets.enc.yaml. 
- Do not use `sops decrypt`

### Environment
- The dev environment is defined with nix. The nix flake is loaded via direnv.
- The shared config value are sourced by the flake
- The secrets are sourced at runtime by the different techs / the command running them

## Additional documentation
Here are additional documentations, read them as needed depending on the task.

## Gotchas (by design — expect them)

- All Proxmox connectivity is TLS-off / token auth: `insecure = true` (terraform) and `validate_certs: false` (ansible) everywhere. Don't "fix" this.
- Provider pins: `bpg/proxmox` 0.104.0 and `carlpett/sops` 1.4.1 in both `main.tf` files.
- Required ansible collections (no `ansible.cfg`): `community.proxmox`, `community.sops`, `community.general`, `ansible.posix`. Installed via `~/.ansible/collections`.
- TF state/plan files are gitignored; `vms/terraform` and `layer1/terraform` have **separate** states.
- Some terraform module `source` paths are hardcoded absolute `~/Repos/homelab/terraform_modules/...`, others relative — the absolute ones bind to the repo author's home dir.
- Dynamic inventory derives `ansible_host` from `proxmox_agent_interfaces[1]` — assumes a specific NIC order on guests.
- Molecule (`just molecule-test`) uses the custom `molecule-proxmox` driver (flake input from `github:NovaWasTakenn/molecule-proxmox`) and requires a **live Proxmox node** with a freshly-clonable VM template (`MOLECULE_PROXMOX_TEMPLATE=template.vm.pve`). It cannot run offline.
- `sops exec-env` exports secrets under the raw key names from `secrets.enc.yaml` (e.g. `proxmox_root_password`), not the `*_ROOT_PASSWORD` style names — cross-check env names before relying on them.
- PVE template/VM naming is significant: `MOLECULE_PROXMOX_TEMPLATE`, template ids, and the `ubuntu`/`basic_vm` tag conventions drive the dynamic inventory groups.

Transient syntax issues and env wiring bugs (likely to be fixed soon) are tracked in `docs/syntax-bugs.md`.
