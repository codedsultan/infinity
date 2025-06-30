#!/usr/bin/env bash
set -euo pipefail

# --- Load configuration from .env file ---
ENV_CONFIG_FILE="$(dirname "$0")/.env.acme"
if [[ -f "$ENV_CONFIG_FILE" ]]; then
  source "$ENV_CONFIG_FILE"
else
  echo "ERROR: Configuration file not found at $ENV_CONFIG_FILE" >&2
  exit 1
fi

# --- Determine the correct user and home directory ---
if [[ -n "$SUDO_USER" ]]; then
  ORIGINAL_USER=$SUDO_USER
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  ORIGINAL_USER=$USER
  USER_HOME=$HOME
fi

# --- Define ACME_HOME and ACME_SH directly ---
ACME_HOME="$USER_HOME/.acme.sh"
ACME_SH="$ACME_HOME/acme.sh"

# --- Configuration Check ---
if [[ -z "${ACME_EMAIL:-}" || -z "${DOMAINS:-}" || -z "${NAMECOM_USERNAME:-}" || -z "${NAMECOM_TOKEN:-}" || -z "${RELOAD_CMD:-}" ]]; then
    echo "ERROR: One or more required variables are not set in $ENV_CONFIG_FILE." >&2
    exit 1
fi

# Set a default value for CERT_DIR
CERT_DIR=${CERT_DIR:-/etc/ssl}

echo "==> Ensuring cert directory exists: $CERT_DIR"
sudo mkdir -p "$CERT_DIR"

# --- Install acme.sh and register account (only if not already installed) ---
if [[ ! -x "$ACME_SH" ]]; then
  echo "==> Installing acme.sh client…"
  sudo -u "$ORIGINAL_USER" curl -fsSL https://get.acme.sh | sh

  echo "==> Registering ACME account with email: $ACME_EMAIL"
  sudo -u "$ORIGINAL_USER" "$ACME_SH" --register-account -m "$ACME_EMAIL"
else
  echo "==> Checking/updating acme.sh client…"
  sudo -u "$ORIGINAL_USER" "$ACME_SH" --upgrade --auto-upgrade
fi

# Export credentials for acme.sh to use
export Namecom_Username="${NAMECOM_USERNAME}"
export Namecom_Token="${NAMECOM_TOKEN}"

# Convert the DOMAINS string from .env into a bash array
read -r -a DOMAINS_ARRAY <<< "$DOMAINS"

# Build domain flags from the array
DOMAIN_FLAGS=()
for d in "${DOMAINS_ARRAY[@]}"; do
  DOMAIN_FLAGS+=("-d" "$d")
done

# Issue the certificate
echo "==> Issuing/renewing certificate for: ${DOMAINS_ARRAY[*]}"
sudo -u "$ORIGINAL_USER" "$ACME_SH" --issue --dns dns_namecom "${DOMAIN_FLAGS[@]}" --ecc "$@"

# Install the certificate
PRIMARY="${DOMAINS_ARRAY[0]}"
echo "==> Installing cert for $PRIMARY into $CERT_DIR"
sudo "$ACME_SH" --install-cert --home "$ACME_HOME" -d "$PRIMARY" --ecc \
  --key-file       "$CERT_DIR/$PRIMARY.key" \
  --fullchain-file "$CERT_DIR/$PRIMARY.crt" \
  --reloadcmd      "$RELOAD_CMD"

# Success message
cat <<EOF

✅ Certificate issued & installed for: ${DOMAINS_ARRAY[*]}
  • Key:   $CERT_DIR/$PRIMARY.key
  • Cert:  $CERT_DIR/$PRIMARY.crt

A daily renewal cron job was configured by acme.sh; on renewal it will run:
  $RELOAD_CMD
EOF