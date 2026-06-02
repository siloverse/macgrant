#!/usr/bin/env bash

set -euo pipefail

VM_IP="${1:-192.168.56.10}"
HOST_IP="${2:-192.168.56.1}"
DOMAIN="${3:-macgrant-platform.test}"

INTERFACE="$(
  ip -o -4 address show |
    awk -v host_ip="$HOST_IP" '
      $4 ~ ("^" host_ip "/") {
        print $2
        exit
      }
    '
)"

if [[ -z "$INTERFACE" ]]; then
  echo "Could not find the interface containing ${HOST_IP}"
  exit 1
fi

echo "Configuring split DNS on ${INTERFACE}"

sudo resolvectl dns "$INTERFACE" "$VM_IP"
sudo resolvectl domain "$INTERFACE" "~${DOMAIN}"
sudo resolvectl default-route "$INTERFACE" no
sudo resolvectl flush-caches

echo "Configured *.${DOMAIN} through ${VM_IP}"