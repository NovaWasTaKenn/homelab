
# Ansible best pratices and procedures

## Overview

Ansible playbooks declare desired system state rather than imperative commands. The core principle is idempotency: running a playbook multiple times produces the same result without unintended changes.

## When to Use

- Creating new playbooks or roles
- Writing inventory files
- Debugging YAML syntax errors
- Troubleshooting module parameter issues
- Understanding variable precedence
- Converting shell scripts to Ansible

## Architecture of a project
- Keep thing simple, only use advanced features when necessary and select the one that best matches the use case
- Declarative over imperative

## Writing playbooks
- Use existing tasks instead of scripts as much as possible
- Maintain idempotency
- Extract repeated automations to roles
- Always mention the state (state: present/absent)
- Use fully qualified collection names
- Roles and playbook should work in check mode and not report changes  when  there are none
- Do not mix roles and tasks sections as the order of execution between them isnt obvious
- Only use tags that work independently. Do not create a tag that doesnt include all the required tasks and that could break stuff if used independently

## Config
- Dont hardcode paths, use magic variables like playbook_dir and role_name. Extract shared vars to config.env, extract playbook / role specific vars to the inventory / var files
- Use dynamic inventory 
- Group inventory based on function to facilitate playbook targeting
- Have single source of truth per piece of information 

## Test
- Check for syntax error : ansible-playbook --syntax-check
- Use --check and --diff

## Secrets
- We dont use ansible vault, we use a  sops encrypted yaml file shared between technos
- No hardcoded secrets
