class profile::tempo (
  String[1] $version,
  Enum['amd64', 'arm64'] $architecture = 'amd64',

  String[1] $listen_address = '127.0.0.1',

  Integer[1, 65535] $http_port          = 3200,
  Integer[1, 65535] $internal_grpc_port = 9095,
  Integer[1, 65535] $otlp_grpc_port     = 4327,
  Integer[1, 65535] $otlp_http_port     = 4328,

  String[1] $config_dir       = '/etc/tempo',
  String[1] $data_dir         = '/data/tempo',
  String[1] $runtime_dir      = '/var/tempo',
  String[1] $retention        = '72h',
  String[1] $package_cache_dir = '/var/cache/macgrant/packages',
) {
  $package_filename = "tempo_${version}_linux_${architecture}.deb"
  $package_path     = "${package_cache_dir}/${package_filename}"
  $checksum_path    = "${package_cache_dir}/tempo-${version}-SHA256SUMS"
  $verified_path    = "${package_path}.verified"

  $release_url = "https://github.com/grafana/tempo/releases/download/v${version}"

  group { 'tempo':
    ensure => present,
    system => true,
  }

  user { 'tempo':
    ensure     => present,
    system     => true,
    gid        => 'tempo',
    shell      => '/usr/sbin/nologin',
    home       => '/nonexistent',
    managehome => false,
    require    => Group['tempo'],
  }

  file { '/data':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec { "download-tempo-${version}":
    command => "/usr/bin/curl --fail --location --silent --show-error --output ${package_path} ${release_url}/${package_filename}",
    creates => $package_path,
    require => [
      Package['curl'],
      File[$package_cache_dir],
    ],
  }

  exec { "download-tempo-checksums-${version}":
    command => "/usr/bin/curl --fail --location --silent --show-error --output ${checksum_path} ${release_url}/SHA256SUMS",
    creates => $checksum_path,
    require => [
      Package['curl'],
      File[$package_cache_dir],
    ],
  }

  exec { "verify-tempo-${version}":
    command => @("COMMAND"/L),
      /bin/bash -c 'set -euo pipefail
      cd "${package_cache_dir}"
      /usr/bin/grep " ${package_filename}\$" "${checksum_path}" \
        | /usr/bin/sha256sum --check --strict -
      /usr/bin/touch "${verified_path}"'
      | COMMAND
  creates => $verified_path,
  require => [
    Exec["download-tempo-${version}"],
    Exec["download-tempo-checksums-${version}"],
  ],
  }

  package { 'tempo':
    ensure   => $version,
    provider => 'apt',
    source   => $package_path,
    require  => [
      Exec["verify-tempo-${version}"],
      User['tempo'],
    ],
  }

  file { $config_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'tempo',
    mode    => '0750',
    require => [
      Package['tempo'],
      User['tempo'],
    ],
  }

  file { $data_dir:
    ensure  => directory,
    owner   => 'tempo',
    group   => 'tempo',
    mode    => '0750',
    require => [
      File['/data'],
      Package['tempo'],
      User['tempo'],
    ]
  }

  file { "${data_dir}/wal":
    ensure  => directory,
    owner   => 'tempo',
    group   => 'tempo',
    mode    => '0750',
    require => File[$data_dir],
  }

  file { "${data_dir}/blocks":
    ensure  => directory,
    owner   => 'tempo',
    group   => 'tempo',
    mode    => '0750',
    require => File[$data_dir],
  }

  file { $runtime_dir:
    ensure  => directory,
    owner   => 'tempo',
    group   => 'tempo',
    mode    => '0750',
    require => [
      Package['tempo'],
      User['tempo'],
    ],
  }

  file { "${config_dir}/config.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'tempo',
    mode    => '0640',
    content => epp('profile/tempo.yml.epp', {
      'listen_address'     => $listen_address,
      'http_port'          => $http_port,
      'internal_grpc_port' => $internal_grpc_port,
      'otlp_grpc_port'     => $otlp_grpc_port,
      'otlp_http_port'     => $otlp_http_port,
      'data_dir'           => $data_dir,
      'runtime_dir'        => $runtime_dir,
      'retention'          => $retention,
    }),
    require => [
      Package['tempo'],
      File[$config_dir],
      File["${data_dir}/wal"],
      File["${data_dir}/blocks"],
      File[$runtime_dir],
      User["tempo"],
    ],
    notify => Service['tempo'],
  }

  service { 'tempo':
    ensure  => running,
    enable  => true,
    require => File["${config_dir}/config.yml"],
  }
}