# @summary Installs and configures the Traefik reverse proxy.
#
# @param binary_path
#   Absolute path where the Traefik binary is installed.
#
# @param config_dir
#   Directory containing the static Traefik configuration.
#
# @param dynamic_config_dir
#   Directory containing dynamically loaded Traefik configuration.
#
# @param private_ip
#   Private IP address on which Traefik exposes its entry points.
class traefik (
  String $binary_path        = '/usr/local/bin/traefik',
  String $config_dir         = '/etc/traefik',
  String $dynamic_config_dir = '/etc/traefik/dynamic',
  String $private_ip         = '192.168.56.10',
) {
  group { 'traefik':
    ensure => present,
    system => true,
  }

  user { 'traefik':
    ensure     => present,
    system     => true,
    gid        => 'traefik',
    home       => '/var/lib/traefik',
    shell      => '/usr/sbin/nologin',
    managehome => true,
    require    => Group['traefik'],
  }

  file { $config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'traefik',
    mode   => '0750',
  }

  file { $dynamic_config_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0750',
    require => File[$config_dir],
  }

  file { '/var/lib/traefik':
    ensure  => directory,
    owner   => 'traefik',
    group   => 'traefik',
    mode    => '0750',
    require => User['traefik'],
  }

  file { '/etc/systemd/system/traefik.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('traefik/traefik.service.epp', {
        'binary_path' => $binary_path,
        'config_file' => "${config_dir}/traefik.yml",
    }),
    notify  => Exec['reload-traefik-systemd'],
  }
  file { '/etc/traefik/certs':
    ensure  => directory,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0750',
    require => File['/etc/traefik'],
  }

  file { '/etc/traefik/certs/macgrant-platform.test.crt':
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0644',
    source  => 'file:///vagrant/.local-certs/macgrant-platform.test.crt',
    require => File['/etc/traefik/certs'],
  }

  file { '/etc/traefik/certs/macgrant-platform.test.key':
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    source  => 'file:///vagrant/.local-certs/macgrant-platform.test.key',
    require => File['/etc/traefik/certs'],
  }

  file { '/etc/traefik/dynamic/tls.yml':
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/tls.yml.epp'),
    require => [
      File['/etc/traefik/dynamic'],
      File['/etc/traefik/certs/macgrant-platform.test.crt'],
      File['/etc/traefik/certs/macgrant-platform.test.key'],
    ],
  }

  file { "${config_dir}/traefik.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/traefik.yml.epp', {
        'dynamic_config_dir' => $dynamic_config_dir,
        'private_ip'         => $private_ip,
    }),
    require => File[$config_dir],
    notify  => Service['traefik'],
  }

  exec { 'reload-traefik-systemd':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Service['traefik'],
  }

  service { 'traefik':
    ensure   => running,
    enable   => true,
    provider => 'systemd',
    require  => [
      User['traefik'],
      File["${config_dir}/traefik.yml"],
      File['/etc/systemd/system/traefik.service'],
    ],
  }
}
