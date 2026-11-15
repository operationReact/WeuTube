#!/usr/bin/env bash
set -euo pipefail
dnf update -y
dnf install -y docker curl jq python3 awscli-2 cronie
systemctl enable --now docker
systemctl enable --now crond
systemctl enable --now amazon-ssm-agent
mkdir -p /usr/local/lib/docker/cli-plugins /opt/weutube/secrets
chmod 0700 /opt/weutube/secrets
curl --fail --location --retry 3 --silent --show-error \
  https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64 \
  --output /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
