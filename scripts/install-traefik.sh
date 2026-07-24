#!/usr/bin/env bash
set -euo pipefail

TRAEFIK_VERSION="3.7.9"
INSTALL_PATH="/usr/local/bin/traefik"

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
  amd64)
    TRAEFIK_ARCH="amd64"
    ;;
  arm64)
    TRAEFIK_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

if [[ -x "$INSTALL_PATH" ]]; then
  INSTALLED_VERSION="$("$INSTALL_PATH" version 2>/dev/null |
    awk '/Version:/ { print $2 }')"

  if [[ "$INSTALLED_VERSION" == "$TRAEFIK_VERSION" ]]; then
    echo "Traefik ${TRAEFIK_VERSION} is already installed"
    exit 0
  fi
fi

echo "Installing Traefik ${TRAEFIK_VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE="traefik_v${TRAEFIK_VERSION}_linux_${TRAEFIK_ARCH}.tar.gz"
BASE_URL="https://github.com/traefik/traefik/releases/download/v${TRAEFIK_VERSION}"

curl -fsSL \
  "${BASE_URL}/${ARCHIVE}" \
  -o "${TMP_DIR}/${ARCHIVE}"

curl -fsSL \
  "${BASE_URL}/traefik_v${TRAEFIK_VERSION}_checksums.txt" \
  -o "${TMP_DIR}/checksums.txt"

cd "$TMP_DIR"

grep " ${ARCHIVE}$" checksums.txt | sha256sum --check

tar -xzf "$ARCHIVE"

install \
  --owner=root \
  --group=root \
  --mode=0755 \
  traefik \
  "$INSTALL_PATH"

"$INSTALL_PATH" version