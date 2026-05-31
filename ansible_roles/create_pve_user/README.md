Create pve automation user
=========

Creates a user with a certain role and an api token
Creates the role if it doesnt exist

Requirements
------------

The community.proxmox.proxmox module

Role Variables
--------------

user_state: present
role_state: present
playbook_user: ""
playbook_password: ""
pve_user: ""
pve_user_password: ""
pve_role: ""
pve_privileges: []

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

License
-------

BSD

