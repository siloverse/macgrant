# @summary Installs and configures Grafana behind Traefik.
#
# Grafana binds only to localhost. Traefik exposes the browser UI through
# the configured HTTPS hostname.
class profile::grafana (
  String[1] $version,
  String[1] $package_revision,
  String[64, 64] $sha256,

  Stdlib::Host $hostname,
  Stdlib::IP::Address $http_address = '127.0.0.1',
  Stdlib::Port $http_port = 3000,

  String[1] $tempo_url = 'http://127.0.0.1:3200',
  String[1] $loki_url = 'http://127.0.0.1:3100',

  String[1] $admin_user = 'admin',
  String[1] $admin_password,
  String[32] $secret_key,

  Enum['amd64', 'arm64'] $architecture = 'amd64',

  Stdlib::Absolutepath $config_dir = '/etc/grafana',
  Stdlib::Absolutepath $data_dir = '/var/lib/grafana',
  Stdlib::Absolutepath $logs_dir = '/var/log/grafana',
  Stdlib::Absolutepath $plugins_dir = '/var/lib/grafana/plugins',

  Stdlib::Absolutepath $package_cache_dir = '/var/cache/macgrant/packages',

  String[1] $prometheus_url = 'http://127.0.0.1:9090',
  String[1] $prometheus_version = '3.13.2',
  String[1] $prometheus_scrape_interval = '15s',
) {
  $package_filename =
    "grafana_${version}_${package_revision}_linux_${architecture}.deb"

  $package_path =
    "${package_cache_dir}/${package_filename}"
  $temporary_package="${package_path}.tmp"
  $package_url =
    "https://dl.grafana.com/grafana/release/${version}/${package_filename}"

  $provisioning_dir =
    "${config_dir}/provisioning"

  $datasources_dir =
    "${provisioning_dir}/datasources"

  # Dependencies required by the official Grafana Debian package.
  package { [
    'adduser',
    'libfontconfig1',
    'musl',
  ]:
    ensure => installed,
  }

  # Download the package only when the cached package is absent or its
  # checksum does not match the expected checksum.
  exec { "download-grafana-${version}":
    command => @("COMMAND"/L),
      /bin/bash -c 'set -euo pipefail

      /usr/bin/rm -f "${temporary_package}"

      /usr/bin/curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --output "${temporary_package}" \
        "${package_url}"

      echo "${sha256}  ${temporary_package}" \
        | /usr/bin/sha256sum --check --strict -

      /usr/bin/mv "${temporary_package}" "${package_path}"'
      | COMMAND

  unless => @("UNLESS"/L),
      /bin/bash -c 'test -f "${package_path}" &&
      echo "${sha256}  ${package_path}" \
        | /usr/bin/sha256sum --check --strict -'
      | UNLESS

  require => [
    Package['curl'],
    File[$package_cache_dir],
  ],
  }

  package { 'grafana':
    ensure   => $version,
    provider => 'apt',
    source   => $package_path,

    require => [
      Exec["download-grafana-${version}"],
      Package['adduser'],
      Package['libfontconfig1'],
      Package['musl'],
    ],
  }

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0750',

    require => Package['grafana'],
  }

  file { [
    $data_dir,
    $logs_dir,
    $plugins_dir,
  ]:
    ensure => directory,
    owner  => 'grafana',
    group  => 'grafana',
    mode   => '0750',

    require => Package['grafana'],
  }

  file { $provisioning_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0750',

    require => [
      Package['grafana'],
      File[$config_dir],
    ],
  }

  file { $datasources_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0750',

    require => File[$provisioning_dir],
  }

  file { "${config_dir}/grafana.ini":
    ensure => file,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0640',

    content => epp('profile/grafana.ini.epp', {
      'hostname'         => $hostname,
      'http_address'     => $http_address,
      'http_port'        => $http_port,
      'admin_user'       => $admin_user,
      'admin_password'   => $admin_password,
      'secret_key'       => $secret_key,
      'data_dir'         => $data_dir,
      'logs_dir'         => $logs_dir,
      'plugins_dir'      => $plugins_dir,
      'provisioning_dir' => $provisioning_dir,
    }),

    require => [
      Package['grafana'],
      File[$config_dir],
      File[$data_dir],
      File[$logs_dir],
      File[$plugins_dir],
      File[$provisioning_dir],
    ],

    notify => Service['grafana-server'],
  }

  file { "${datasources_dir}/tempo.yaml":
    ensure => file,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0640',

    content => epp('profile/grafana-tempo-datasource.yaml.epp', {
      'tempo_url' => $tempo_url,
    }),

    require => [
      Package['grafana'],
      File[$datasources_dir],
    ],

    notify => Service['grafana-server'],
  }

  file { "${datasources_dir}/prometheus.yaml":
    ensure => file,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0640',

    content => epp(
      'profile/grafana-prometheus-datasource.yaml.epp',
      {
        'prometheus_url'             => $prometheus_url,
        'prometheus_version'         => $prometheus_version,
        'scrape_interval'            => $prometheus_scrape_interval,
      },
    ),

    require => [
      Package['grafana'],
      File[$datasources_dir],
    ],

    notify => Service['grafana-server'],
  }

  file { "${datasources_dir}/loki.yaml":
    ensure => file,
    owner  => 'root',
    group  => 'grafana',
    mode   => '0640',

    content => epp('profile/grafana-loki-datasource.yaml.epp', {
      'loki_url' => $loki_url,
    }),

    require => [
      Package['grafana'],
      File[$datasources_dir],
    ],

    notify => Service['grafana-server'],
  }

  service { 'grafana-server':
    ensure => running,
    enable => true,

    require => [
      File["${config_dir}/grafana.ini"],
      File["${datasources_dir}/tempo.yaml"],
      File["${datasources_dir}/prometheus.yaml"],
      File["${datasources_dir}/loki.yaml"],
    ],
  }

  # Browser access:
  #
  # https://grafana.macgrant-platform.test
  #   -> Traefik
  #   -> http://127.0.0.1:3000
  traefik::http_route { 'grafana':
    hostname => $hostname,
    target   => "http://${http_address}:${http_port}",
    tls      => true,
  }

  Service['grafana-server']
  -> Traefik::Http_route['grafana']
}
