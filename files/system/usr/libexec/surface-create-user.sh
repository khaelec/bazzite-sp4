#!/usr/bin/env bash
# Creates the default desktop user on first boot. Idempotent.
set -euo pipefail

USER_NAME="ulrick"
FLAG="/var/lib/surface-user-created"

if id "${USER_NAME}" >/dev/null 2>&1; then
    touch "${FLAG}"
    exit 0
fi

useradd -m -G wheel -c "Ulrick" "${USER_NAME}"
echo "${USER_NAME}:changeme" | chpasswd
chage -d 0 "${USER_NAME}"   # force a password change at first login
touch "${FLAG}"
