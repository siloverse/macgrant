#!/usr/bin/env bash
set -euo pipefail

if ! command -v puppet >/dev/null 2>&1; then
  apt-get update
  apt-get install -y wget ca-certificates

  wget -q https://apt.puppet.com/puppet8-release-noble.deb -O /tmp/puppet8-release-noble.deb
  dpkg -i /tmp/puppet8-release-noble.deb

  apt-get update
  apt-get install -y puppet-agent

  ln -sf /opt/puppetlabs/bin/puppet /usr/local/bin/puppet
fi