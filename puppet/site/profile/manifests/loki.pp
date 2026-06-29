# @summary Installs and configures Grafana Loki for local log storage.
#
# Loki runs in single-binary mode, stores logs on the local filesystem, and
# binds only to loopback. It is an internal backend and has no Traefik route.
class profile::loki (
  String[1] $version,
  String[64, 64] $sha256,

  Stdlib::IP::Address $http_address = '127.0.0.1',
  Stdlib::Port $http_port = 3100,

  Stdlib::IP::Address $grpc_address = '127.0.0.1',
  Stdlib::Port $grpc_port = 9096,

  String[1] $retention_period = '168h',

  Enum['amd64', 'arm64'] $architecture = 'amd64',

  Stdlib::Absolutepath $config_dir = '/etc/loki',
  Stdlib::Absolutepath $data_dir = '/var/lib/loki',
  Stdlib::Absolutepath $install_root = '/opt',
  Stdlib::Absolutepath $package_cache_dir = '/var/cache/macgrant/packages',
  Stdlib::Absolutepath $service_unit = '/etc/systemd/system/loki.service',
) {
  $archive_filename = "loki-linux-${architecture}.zip"
  $archive_path = "${package_cache_dir}/${archive_filename}"
  $temporary_archive = "${archive_path}.tmp"
  $release_url = "https://github.com/grafana/loki/releases/download/v${version}/${archive_filename}"

  $install_dir = "${install_root}/loki-${version}"
  $installed_binary = "${install_dir}/loki-linux-${architecture}"

  $config_file = "${config_dir}/loki.yml"
  $chunks_dir = "${data_dir}/chunks"
  $rules_dir = "${data_dir}/rules"
  $compactor_dir = "${data_dir}/compactor"

  group { 'loki':
    ensure => present,
    system => true,
  }

  user { 'loki':
    ensure     => present,
    system     => true,
    gid        => 'loki',
    home       => $data_dir,
    shell      => '/usr/sbin/nologin',
    managehome => false,

    require => Group['loki'],
  }

  exec { "download-loki-${version}":
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

  file { $install_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec { "extract-loki-${version}":
    command => "/usr/bin/unzip -q ${archive_path} -d ${install_dir}",
    creates => $installed_binary,
    timeout => 300,

    require => [
      Exec["download-loki-${version}"],
      File[$install_dir],
      Package['unzip'],
    ],
  }

  file { $installed_binary:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',

    require => Exec["extract-loki-${version}"],
  }

  file { '/usr/local/bin/loki':
    ensure => link,
    target => $installed_binary,

    require => File[$installed_binary],
    notify  => Service['loki'],
  }

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'loki',
    mode   => '0750',

    require => Group['loki'],
  }

  file { $data_dir:
    ensure => directory,
    owner  => 'loki',
    group  => 'loki',
    mode   => '0750',

    require => User['loki'],
  }

  file { [
    $chunks_dir,
    $rules_dir,
    $compactor_dir,
  ]:
    ensure => directory,
    owner  => 'loki',
    group  => 'loki',
    mode   => '0750',

    require => File[$data_dir],
  }

  file { $config_file:
    ensure => file,
    owner  => 'root',
    group  => 'loki',
    mode   => '0640',

    content => epp('profile/loki.yml.epp', {
      'http_address'     => $http_address,
      'http_port'        => $http_port,
      'grpc_address'     => $grpc_address,
      'grpc_port'        => $grpc_port,
      'retention_period' => $retention_period,
      'data_dir'         => $data_dir,
      'chunks_dir'       => $chunks_dir,
      'rules_dir'        => $rules_dir,
      'compactor_dir'    => $compactor_dir,
    }),

    validate_cmd => '/usr/local/bin/loki -verify-config -config.file=%',

    require => [
      File['/usr/local/bin/loki'],
      File[$config_dir],
      File[$chunks_dir],
      File[$rules_dir],
      File[$compactor_dir],
    ],

    notify => Service['loki'],
  }

  file { $service_unit:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',

    content => epp('profile/loki.service.epp', {
      'config_file' => $config_file,
      'data_dir'    => $data_dir,
    }),

    require => [
      File['/usr/local/bin/loki'],
      File[$config_file],
      File[$data_dir],
    ],

    notify => Exec['loki-systemd-daemon-reload'],
  }

  exec { 'loki-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,

    notify => Service['loki'],
  }

  service { 'loki':
    ensure   => running,
    enable   => true,
    provider => 'systemd',

    require => [
      File[$service_unit],
      File[$config_file],
      File['/usr/local/bin/loki'],
      File[$data_dir],
    ],
  }
}
