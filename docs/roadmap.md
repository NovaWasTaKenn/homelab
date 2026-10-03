# Roadmap

This document tracks the remaining work to bring the homelab to a fully automated, production-grade state.

---

## In Progress

IMPORTANT : setup  gitlfs for pxe boot files

- Review usage of templates for proxmox vms and move away from it (terraform)
- Fix assignment of vm / container to a node. Right now target_node needs to be manually specified / reassigned if the node changes name

3. **Fix syntax issues caused by the refactor**
   - See `docs/syntax-bugs.md` for the current list
   - Re-verify each bug before acting on it

4. **Complete `justfile` recipes**
   - Add recipes for Terraform plan/apply per layer
   - Add recipes for Ansible playbook runs (bootstrap, cluster, restore)
   - Goal: deployment as close to one command as possible

5. **Destroy and re-test full deployment**
   - Tear down the existing infrastructure
   - Run the complete PXE → bootstrap → Terraform → Ansible flow end-to-end
   - Validate that every service comes back correctly

6. **Kubernetes layer**
   - Choose and deploy a GitOps operator (Flux or ArgoCD)
   - Populate `infra_components/kubernetes_base/` (CNI, CSI, monitoring)
   - Populate `infra_components/kubernetes_apps/` (applications)

- Clean up vm layer. Particularly template storage / other system usecases shared storage
    - Do we keep the iscsi patch or figure out some other way?

- Think about license at some point

- Network discovery dynamic inventory to get the nodes and their info
- Verify Proxmox provider `ssh` block usefulness during `terraform plan/apply` tests
- Test SDN resources (`sdn.tf`) — VXLAN zone, VNet, and appliers have never been applied
- Verify `opnsense-backup-container` module (renamed from `opnsense-bakcup-container`) deploys correctly

---

## OPNsense / Backup

- **SOPS secrets to add**:
  - `opnsense_api_key`
  - `opnsense_api_secret`
  - `git_deploy_key`
- **Terraform tag**: Add `opnsense-backup` tag to the `opnsense-bakcup-container` module so the dynamic inventory plugin can discover the backup container
- **Inventory migration**: Once the tag is added, migrate `opnsense_backup` group from static to dynamic discovery via `community.proxmox.proxmox` inventory plugin
- **Role cleanup**: Remove the unused `configure_opnsense_backup_job` Ansible role (tasks are now in the playbook)

---

## Deferred (Document Later)

- **Step-by-step deployment runbook** — detailed commands for a full greenfield install
- **`justfile` recipe documentation** — usage examples and required environment variables for each recipe
- **PXE boot workflow documentation** — how the iPXE chain works, DHCP option configuration, and answer file generation
