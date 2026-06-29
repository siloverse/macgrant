# @summary Installs and configures OpenTelemetry Collector Contrib.
#
# The Collector receives OTLP telemetry from applications and forwards
# traces to Grafana Tempo and logs to Grafana Loki.
class profile::opentelemetry_collector (
  String[1] $version,
  Stdlib::Host $hostname                         = 'otel.macgrant-platform.test',
  Stdlib::IP::Address $listen_address            = '127.0.0.1',
  Stdlib::Port $otlp_grpc_port                   = 4317,
  Stdlib::Port $otlp_http_port                   = 4318,
  String[1] $grpc_route_entry_point              = 'otel_grpc',
  String[1] $tempo_endpoint                      = '127.0.0.1:4327',
  String[1] $loki_endpoint                       = 'http://127.0.0.1:3100/otlp',
  Stdlib::IP::Address $health_address            = '127.0.0.1',
  Stdlib::Port $health_port                      = 13133,
  Stdlib::IP::Address $metrics_address           = '127.0.0.1',
  Stdlib::Port $metrics_port                     = 8888,
  Integer[1] $memory_limit_mib                   = 256,
  Integer[1] $memory_spike_limit_mib             = 64,
  Enum['amd64', 'arm64'] $architecture           = 'amd64',
  Stdlib::Absolutepath $config_dir               = '/etc/otelcol-contrib',
  Stdlib::Absolutepath $package_cache_dir        = '/var/cache/macgrant/packages',
) {
  $package_filename          = "otelcol-contrib_${version}_linux_${architecture}.deb"
  $package_path              = "${package_cache_dir}/${package_filename}"
  $checksum_filename         = "otelcol-contrib-${version}-checksums.txt"
  $checksum_path             = "${package_cache_dir}/${checksum_filename}"
  $release_checksum_filename = 'opentelemetry-collector-releases_otelcol-contrib_checksums.txt'
  $verified_path             = "${package_path}.verified"
  $release_url               = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${version}"
  $systemd_override_dir      = '/etc/systemd/system/otelcol-contrib.service.d'
  $systemd_override_file     = "${systemd_override_dir}/10-puppet-config-ready.conf"
  $config_ready_file         = "${config_dir}/.puppet-config-ready"

  # The upstream package starts its bundled default configuration from
  # postinst. Gate startup until Puppet has installed and validated the
  # loopback-only configuration so the defaults never bind public interfaces.
  file { $systemd_override_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { $systemd_override_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[Unit]\nConditionPathExists=${config_ready_file}\n",
    require => File[$systemd_override_dir],
  }

  exec { "download-opentelemetry-collector-${version}":
    command => "/usr/bin/curl --fail --location --silent --show-error --output ${package_path} ${release_url}/${package_filename}",
    creates => $package_path,
    require => [
      Package['curl'],
      File[$package_cache_dir],
    ],
  }

  exec { "download-opentelemetry-collector-checksum-${version}":
    command => "/usr/bin/curl --fail --location --silent --show-error --output ${checksum_path} ${release_url}/${release_checksum_filename}",
    creates => $checksum_path,
    require => [
      Package['curl'],
      File[$package_cache_dir],
    ],
  }

  exec { "verify-opentelemetry-collector-${version}":
    command => @("COMMAND"/L),
      /bin/bash -c 'set -euo pipefail
      cd "${package_cache_dir}"
      /usr/bin/grep " ${package_filename}\$" "${checksum_path}" \
        | /usr/bin/sha256sum --check --strict -
      /usr/bin/touch "${verified_path}"'
      | COMMAND
    creates => $verified_path,
    require => [
      Exec["download-opentelemetry-collector-${version}"],
      Exec["download-opentelemetry-collector-checksum-${version}"],
    ],
  }

  package { 'otelcol-contrib':
    ensure   => $version,
    provider => 'apt',
    source   => $package_path,
    require  => [
      Exec["verify-opentelemetry-collector-${version}"],
      File[$systemd_override_file],
    ],
  }

  exec { 'reload-opentelemetry-collector-systemd':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File[$systemd_override_file],
    require     => Package['otelcol-contrib'],
  }

  file { $config_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'otelcol-contrib',
    mode    => '0750',
    require => Package['otelcol-contrib'],
  }

  file { "${config_dir}/config.yaml":
    ensure       => file,
    owner        => 'root',
    group        => 'otelcol-contrib',
    mode         => '0640',
    content      => epp('profile/opentelemetry-collector.yaml.epp', {
      'listen_address'         => $listen_address,
      'otlp_grpc_port'         => $otlp_grpc_port,
      'otlp_http_port'         => $otlp_http_port,
      'health_address'         => $health_address,
      'health_port'            => $health_port,
      'metrics_address'        => $metrics_address,
      'metrics_port'           => $metrics_port,
      'tempo_endpoint'         => $tempo_endpoint,
      'loki_endpoint'          => $loki_endpoint,
      'memory_limit_mib'       => $memory_limit_mib,
      'memory_spike_limit_mib' => $memory_spike_limit_mib,
    }),
    validate_cmd => '/usr/bin/otelcol-contrib validate --config=%',
    require      => [
      Package['otelcol-contrib'],
      File[$config_dir],
    ],
    notify       => Service['otelcol-contrib'],
  }

  file { $config_ready_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "Managed by Puppet.\n",
    require => File["${config_dir}/config.yaml"],
  }

  service { 'otelcol-contrib':
    ensure   => running,
    enable   => true,
    provider => 'systemd',
    require  => [
      Exec['reload-opentelemetry-collector-systemd'],
      File[$config_ready_file],
    ],
  }

  # Services inside the VM can access the Collector directly without
  # passing through the host-only Traefik listeners.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  # OTLP/HTTP:
  #
  # https://otel.macgrant-platform.test/v1/traces
  #   -> Traefik websecure
  #   -> http://127.0.0.1:4318/v1/traces
  traefik::http_route { 'opentelemetry-collector-http':
    hostname => $hostname,
    target   => "http://${listen_address}:${otlp_http_port}",
    tls      => true,
  }

  # OTLP/gRPC:
  #
  # otel.macgrant-platform.test:4317
  #   -> Traefik TCP entry point
  #   -> 127.0.0.1:4317
  traefik::tcp_route { 'opentelemetry-collector-grpc':
    entry_point => $grpc_route_entry_point,
    target      => "${listen_address}:${otlp_grpc_port}",
  }

  Service['otelcol-contrib'] -> Traefik::Http_route['opentelemetry-collector-http']
  Service['otelcol-contrib'] -> Traefik::Tcp_route['opentelemetry-collector-grpc']
}
