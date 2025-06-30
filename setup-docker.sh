#!/usr/bin/env bash
set -e

# setup-docker.sh — Install Docker & Docker Compose v2 plugin on Ubuntu 22.04
# Usage: sudo bash setup-docker.sh

# 1. Update apt and install prerequisites
apt update
apt install -y ca-certificates curl gnupg lsb-release

# 2. Add Docker’s official GPG key and repository
mkdir -p /etc/apt/keyrings
test -f /etc/apt/keyrings/docker.gpg || \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
   https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

# 3. Install Docker Engine & CLI
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# 4. (Optional) Install Docker Compose v2 plugin
apt install -y docker-compose-plugin

# 5. Add current user to the docker group (requires logout/login to apply)
usermod -aG docker "$SUDO_USER"

cat <<EOF

✅ Docker installation complete.
• Run 'exit' and reconnect or log in again to apply group changes.
• Verify with 'docker version' and 'docker compose version'.
EOF
