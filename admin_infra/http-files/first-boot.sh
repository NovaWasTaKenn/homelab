#!/bin/bash
# Runs on the freshly installed Proxmox node at first boot (fully-up stage)
# Sets up the ansible user and SSH key so Ansible can take over immediately

set -euo pipefail

ANSIBLE_USER="ansible"
# Replace with your actual SSH public key
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIKSM75OKaSg4wHcZeL4f/bpb9h3mhulxxmbPC4llqij quentin@nixos"

# Create ansible user and add to ssh users group
useradd -m -s /bin/bash "$ANSIBLE_USER"

groupadd sshusers
usermod -a -G sshusers ansible

# Passwordless sudo
echo "$ANSIBLE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# SSH key
mkdir -p /home/$ANSIBLE_USER/.ssh
echo "$SSH_PUBLIC_KEY" > /home/$ANSIBLE_USER/.ssh/authorized_keys
chown -R $ANSIBLE_USER:$ANSIBLE_USER /home/$ANSIBLE_USER/.ssh
chmod 700 /home/$ANSIBLE_USER/.ssh
chmod 600 /home/$ANSIBLE_USER/.ssh/authorized_keys

# Harden SSH

cat > /etc/ssh/sshd_config << 'EOF'
Protocol 2
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AllowGroups sshusers
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
AllowAgentForwarding no
AllowTcpForwarding no
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
UsePAM yes
AcceptEnv LANG LC_* COLORTERM NO_COLOR
Subsystem sftp /usr/lib/openssh/sftp-server
PrintMotd yes
EOF

systemctl restart sshd

echo "First boot setup complete"
