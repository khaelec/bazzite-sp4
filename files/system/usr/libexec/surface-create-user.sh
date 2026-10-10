#!/usr/bin/env bash
# Creates the default desktop user and ALWAYS (re)sets its password on first
# boot. Idempotent: does nothing once it has run successfully.
set -euo pipefail

USER_NAME="ulrick"
FLAG="/var/lib/surface-user-created"

[ -e "${FLAG}" ] && exit 0

if ! id "${USER_NAME}" >/dev/null 2>&1; then
    useradd -m -G wheel -c "Ulrick" "${USER_NAME}"
fi

# Set the password regardless of whether the user was just created or already
# existed (e.g. created by bootc-image-builder customizations).
echo "${USER_NAME}:changeme" | chpasswd

touch "${FLAG}"
