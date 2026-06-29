# @summary Installs and configures Prometheus behind Traefik.
#
# Prometheus binds to localhost and scrapes metrics from the local
# observability components. Traefik exposes its web interface through HTTPS.
class profile::prometheus (
  String[1] $version,
  String[64, 64] $sha256,

  Stdlib::Host $hostname,

  Stdlib::IP::Address $listen_address = '127.0.0.1',
  Stdlib::Port $port = 9090,

  String[1] $scrape_interval = '15s',
  String[1] $evaluation_interval = '15s',
  String[1] $retention_time = '7d',
  String[1] $retention_size = '2GB',

  Stdlib::IP::Address $node_exporter_address = '127.0.0.1',
  Stdlib::Port $node_exporter_port = 9100,

  Stdlib::IP::Address $collector_metrics_address = '127.0.0.1',
  Stdlib::Port $collector_metrics_port = 8888,

  Stdlib::IP::Address $tempo_metrics_address = '127.0.0.1',
  Stdlib::Port $tempo_metrics_port = 3200,

  Stdlib::IP::Address $loki_metrics_address = '127.0.0.1',
  Stdlib::Port $loki_metrics_port = 3100,

  Stdlib::IP::Address $grafana_metrics_address = '127.0.0.1',
  Stdlib::Port $grafana_metrics_port = 3000,

  Enum['amd64', 'arm64'] $architecture = 'amd64',

  Stdlib::Absolutepath $config_dir = '/etc/prometheus',
  Stdlib::Absolutepath $data_dir = '/var/lib/prometheus',
  Stdlib::Absolutepath $install_root = '/opt',
  Stdlib::Absolutepath $package_cache_dir = '/var/cache/macgrant/packages',
  Stdlib::Absolutepath $service_unit = '/etc/systemd/system/prometheus.service',
) {
  $archive_filename =
    "prometheus-${version}.linux-${architecture}.tar.gz"

  $archive_path =
    "${package_cache_dir}/${archive_filename}"

  $install_dir =
    "${install_root}/prometheus-${version}.linux-${architecture}"

  $release_url =
    "https://github.com/prometheus/prometheus/releases/download/v${version}/${archive_filename}"

  $config_file =
    "${config_dir}/prometheus.yml"

  group { 'prometheus':
    ensure => present,
    system => true,
  }

  user { 'prometheus':
    ensure     => present,
    system     => true,
    gid        => 'prometheus',
    home       => $data_dir,
    shell      => '/usr/sbin/nologin',
    managehome => false,

    require => Group['prometheus'],
  }

  exec { "download-prometheus-${version}":
    command => @("COMMAND"/L),
      /bin/bash -c 'set -euo pipefail

      /usr/bin/rm -f "${archive_path}.tmp"

      /usr/bin/curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --output "${archive_path}.tmp" \
        "${release_url}"

      echo "${sha256}  ${archive_path}.tmp" \
        | /usr/bin/sha256sum --check --strict -

      /usr/bin/mv "${archive_path}.tmp" "${archive_path}"'
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

  exec { "extract-prometheus-${version}":
    command => join([
      '/bin/tar',
      '--extract',
      '--gzip',
      "--file=${archive_path}",
      "--directory=${install_root}",
      '--no-same-owner',
    ], ' '),

    creates => "${install_dir}/prometheus",
    timeout => 300,

    require => Exec["download-prometheus-${version}"],
  }

  file { '/usr/local/bin/prometheus':
    ensure => link,
    target => "${install_dir}/prometheus",

    require => Exec["extract-prometheus-${version}"],
  }

  file { '/usr/local/bin/promtool':
    ensure => link,
    target => "${install_dir}/promtool",

    require => Exec["extract-prometheus-${version}"],
  }

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'prometheus',
    mode   => '0750',

    require => Group['prometheus'],
  }

  file { $data_dir:
    ensure => directory,
    owner  => 'prometheus',
    group  => 'prometheus',
    mode   => '0750',

    require => User['prometheus'],
  }

  file { $config_file:
    ensure => file,
    owner  => 'root',
    group  => 'prometheus',
    mode   => '0640',

    content => epp('profile/prometheus.yml.epp', {
      'listen_address'           => $listen_address,
      'port'                     => $port,
      'scrape_interval'          => $scrape_interval,
      'evaluation_interval'      => $evaluation_interval,
      'retention_time'           => $retention_time,
      'retention_size'           => $retention_size,
      'node_exporter_address'     => $node_exporter_address,
      'node_exporter_port'        => $node_exporter_port,
      'collector_metrics_address' => $collector_metrics_address,
      'collector_metrics_port'   => $collector_metrics_port,
      'tempo_metrics_address'    => $tempo_metrics_address,
      'tempo_metrics_port'       => $tempo_metrics_port,
      'loki_metrics_address'     => $loki_metrics_address,
      'loki_metrics_port'        => $loki_metrics_port,
      'grafana_metrics_address'  => $grafana_metrics_address,
      'grafana_metrics_port'     => $grafana_metrics_port,
    }),

    validate_cmd => "${install_dir}/promtool check config %",

    require => [
      Exec["extract-prometheus-${version}"],
      File[$config_dir],
    ],

    notify => Service['prometheus'],
  }

  file { $service_unit:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',

    content => epp('profile/prometheus.service.epp', {
      'hostname'         => $hostname,
      'listen_address'   => $listen_address,
      'port'             => $port,
      'config_file'      => $config_file,
      'data_dir'         => $data_dir,
      'install_dir'      => $install_dir,
    }),

    require => [
      Exec["extract-prometheus-${version}"],
      File[$config_file],
      File[$data_dir],
    ],

    notify => Exec['prometheus-systemd-daemon-reload'],
  }

  exec { 'prometheus-systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,

    notify => Service['prometheus'],
  }

  service { 'prometheus':
    ensure => running,
    enable => true,

    require => [
      File[$service_unit],
      File[$config_file],
      File['/usr/local/bin/prometheus'],
      File['/usr/local/bin/promtool'],
    ],
  }

  # Browser access:
  #
  # https://prometheus.macgrant-platform.test
  #   -> Traefik
  #   -> http://127.0.0.1:9090
  traefik::http_route { 'prometheus':
    hostname => $hostname,
    target   => "http://${listen_address}:${port}",
    tls      => true,
  }

  Service['prometheus']
  -> Traefik::Http_route['prometheus']
}
