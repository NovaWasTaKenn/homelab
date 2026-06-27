#!/bin/bash
# Runs on the freshly installed Proxmox node at first boot (fully-up stage)
# Sets up the ansible user and SSH key so Ansible can take over immediately

set -euo pipefail

ANSIBLE_USER="ansible"
# Replace with your actual SSH public key
SSH_PUBLIC_KEY="ssh-ed25519 AAAA... your-key-here"

# Create ansible user
useradd -m -s /bin/bash "$ANSIBLE_USER"

# Passwordless sudo
echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# SSH key
mkdir -p /home/$ANSIBLE_USER/.ssh
echo "$SSH_PUBLIC_KEY" > /home/$ANSIBLE_USER/.ssh/authorized_keys
chown -R $ANSIBLE_USER:$ANSIBLE_USER /home/$ANSIBLE_USER/.ssh
chmod 700 /home/$ANSIBLE_USER/.ssh
chmod 600 /home/$ANSIBLE_USER/.ssh/authorized_keys

# Root SSH key too (for bootstrap playbook)
mkdir -p /root/.ssh
echo "$SSH_PUBLIC_KEY" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Harden SSH
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "First boot setup complete"
