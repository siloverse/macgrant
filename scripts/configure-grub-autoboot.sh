#!/usr/bin/env bash
set -euo pipefail

echo "Configuring GRUB for unattended Vagrant boot..."

install -d -m 0755 /etc/default/grub.d

cat > /etc/default/grub.d/99-vagrant-autoboot.cfg <<'EOF'
# Always boot the first Ubuntu entry automatically.
GRUB_DEFAULT=0

# Show the menu briefly, then continue automatically.
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=2

# Do not wait indefinitely after a failed or forced shutdown.
GRUB_RECORDFAIL_TIMEOUT=2
EOF

# Remove an existing failed-boot marker.
if command -v grub-editenv >/dev/null 2>&1; then
    grub-editenv /boot/grub/grubenv unset recordfail || true
fi

update-grub

echo "GRUB unattended boot configuration completed."