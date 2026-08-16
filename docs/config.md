
Vars
Declare env vars in a global env file -> source the vars with .envrc
Ansible reads env vars with lookup
Terraform with TF_VAR_...
Molecule uses env vars by default

Secrets
Use sops.sops with lookup to load sops vars in the inventory


Terraform uses carlpett/sops to get the sops file as a data source. Gets the path of the sops file through TF_VAR env var

Molecule
Perhaps makefile/justfile/alias and sops exec-env molecule.test
