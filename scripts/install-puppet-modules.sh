#!/usr/bin/env bash
set -euo pipefail

MODULE_PATH="/vagrant/puppet/modules"
SYSTEMD_VERSION="8.3.1"

mkdir -p "$MODULE_PATH"

if ! grep -q "\"version\": \"${SYSTEMD_VERSION}\"" "$MODULE_PATH/systemd/metadata.json" 2>/dev/null; then
  /opt/puppetlabs/bin/puppet module install puppet-systemd --version "$SYSTEMD_VERSION" --modulepath "$MODULE_PATH" --force
fi

if [ ! -d "$MODULE_PATH/postgresql" ]; then
  /opt/puppetlabs/bin/puppet module install puppetlabs-postgresql --version 10.6.2 --modulepath "$MODULE_PATH"
fi

if [ ! -d "$MODULE_PATH/redis" ]; then
  /opt/puppetlabs/bin/puppet module install puppet-redis --version 13.0.0 --modulepath "$MODULE_PATH"
fi

if [ ! -d "$MODULE_PATH/keycloak" ]; then
  /opt/puppetlabs/bin/puppet module install treydock-keycloak --version 14.2.0 --modulepath "$MODULE_PATH"
fi
