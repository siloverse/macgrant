# @summary Installs and configures Prometheus Node Exporter.
#
# Node Exporter exposes operating-system and hardware metrics to Prometheus.
# It binds only to localhost and is not exposed through Traefik.
class profile::node_exporter (
  String[1] $version,
  String[64, 64] $sha256,

  Stdlib::IP::Address $listen_address = '127.0.0.1',
  Stdlib::Port $port = 9100,

  Enum['amd64', 'arm64'] $architecture = 'amd64',

  Stdlib::Absolutepath $install_root = '/opt',
  Stdlib::Absolutepath $package_cache_dir = '/var/cache/macgrant/packages',
  Stdlib::Absolutepath $data_dir = '/var/lib/node_exporter',
  Stdlib::Absolutepath $textfile_collector_dir = '/var/lib/node_exporter/textfile_collector',
  Stdlib::Absolutepath $service_unit = '/etc/systemd/system/node_exporter.service',
) {
  $archive_filename =
    "node_exporter-${version}.linux-${architecture}.tar.gz"

  $archive_path =
    "${package_cache_dir}/${archive_filename}"
  $temporary_archive = "${archive_path}.tmp"

  $install_dir =
    "${install_root}/node_exporter-${version}.linux-${architecture}"

  $release_url =
    "https://github.com/prometheus/node_exporter/releases/download/v${version}/${archive_filename}"

  group { 'node_exporter':
    ensure => present,
    system => true,
  }

  user { 'node_exporter':
    ensure     => present,
    system     => true,
    gid        => 'node_exporter',
    home       => $data_dir,
    shell      => '/usr/sbin/nologin',
    managehome => false,

    require => Group['node_exporter'],
  }

  exec { "download-node-exporter-${version}":
    command => @("COMMAND"/L),
      /bin/bash -c 'set -euo pipefail

      /usr/bin/rm -f "${temporary_archive}"

      /usr/bin/curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --output "${temporary_archive}" \
        "${release_url}"

      echo "${sha256}  ${temporary_archive}" \
        | /usr/bin/sha256sum --check --strict -

      /usr/bin/mv "${temporary_archive}" "${archive_path}"'
      | COMMAND

  unless => @("UNLESS"/L),
      /bin/bash -c 'test -f "${archive_path}" &&
      echo "${sha256}  ${archive_path}" \
        | /usr/bin/sha256sum --check --status -'
      | UNLESS

  timeout => 300,

  require => [
    Package['curl'],
    File[$package_cache_dir],
  ],
  }

  exec { "extract-node-exporter-${version}":
    command => join([
      '/bin/tar',
      '--extract',
      '--gzip',
      "--file=${archive_path}",
      "--directory=${install_root}",
      '--no-same-owner',
    ], ' '),

    creates => "${install_dir}/node_exporter",
    timeout => 300,

    require => Exec["download-node-exporter-${version}"],
  }

  file { '/usr/local/bin/node_exporter':
    ensure => link,
    target => "${install_dir}/node_exporter",

    require => Exec["extract-node-exporter-${version}"],
  }

  file { $data_dir:
    ensure => directory,
    owner  => 'node_exporter',
    group  => 'node_exporter',
    mode   => '0750',

    require => User['node_exporter'],
  }

  file { $textfile_collector_dir:
    ensure => directory,
    owner  => 'node_exporter',
    group  => 'node_exporter',
    mode   => '0750',

    require => File[$data_dir],
  }

  file { $service_unit:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',

    content => epp('profile/node-exporter.service.epp', {
      'listen_address'         => $listen_address,
      'port'                   => $port,
      'textfile_collector_dir' => $textfile_collector_dir,
    }),

    require => [
      File['/usr/local/bin/node_exporter'],
      File[$textfile_collector_dir],
    ],

    notify => Exec['node-exporter-systemd-daemon-reload'],
  }

  exec { 'node-exporter-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,

    notify => Service['node_exporter'],
  }

  service { 'node_exporter':
    ensure => running,
    enable => true,

    require => [
      File[$service_unit],
      File['/usr/local/bin/node_exporter'],
      File[$textfile_collector_dir],
    ],
  }
}
