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
#
# @param tcp_entry_points
#   Mapping of TCP entry-point names to ports on the private IP.
#
# @param certificate_name
#   Basename used for the installed certificate and key.
#
# @param certificate_source_crt
#   Puppet file source for the certificate.
#
# @param certificate_source_key
#   Puppet file source for the private key.
#
# @param data_dir
#   Working directory for the Traefik service user.
#
# @param systemd_unit
#   Path to the Traefik systemd unit.
class traefik (
  Stdlib::IP::Address $private_ip,
  Hash[String[1], Stdlib::Port] $tcp_entry_points,
  String[1] $certificate_name,
  String[1] $certificate_source_crt,
  String[1] $certificate_source_key,
  Stdlib::Absolutepath $binary_path        = '/usr/local/bin/traefik',
  Stdlib::Absolutepath $config_dir         = '/etc/traefik',
  Stdlib::Absolutepath $dynamic_config_dir = '/etc/traefik/dynamic',
  Stdlib::Absolutepath $data_dir           = '/var/lib/traefik',
  Stdlib::Absolutepath $systemd_unit       = '/etc/systemd/system/traefik.service',
) {
  $certs_dir       = "${config_dir}/certs"
  $certificate_crt = "${certs_dir}/${certificate_name}.crt"
  $certificate_key = "${certs_dir}/${certificate_name}.key"
  $config_file     = "${config_dir}/traefik.yml"
  $tls_config_file = "${dynamic_config_dir}/tls.yml"

  group { 'traefik':
    ensure => present,
    system => true,
  }

  user { 'traefik':
    ensure     => present,
    system     => true,
    gid        => 'traefik',
    home       => $data_dir,
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

  file { $data_dir:
    ensure  => directory,
    owner   => 'traefik',
    group   => 'traefik',
    mode    => '0750',
    require => User['traefik'],
  }

  exec { 'require-traefik-binary':
    command => "/usr/bin/test -x ${binary_path}",
    unless  => "/usr/bin/test -x ${binary_path}",
  }

  file { $systemd_unit:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('traefik/traefik.service.epp', {
      'binary_path' => $binary_path,
      'config_file' => $config_file,
      'data_dir'    => $data_dir,
    }),
    notify  => Exec['reload-traefik-systemd'],
  }

  file { $certs_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0750',
    require => File[$config_dir],
  }

  file { $certificate_crt:
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0644',
    source  => $certificate_source_crt,
    require => File[$certs_dir],
  }

  file { $certificate_key:
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    source  => $certificate_source_key,
    require => File[$certs_dir],
  }

  file { $tls_config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/tls.yml.epp', {
      'certificate_file' => $certificate_crt,
      'certificate_key'  => $certificate_key,
    }),
    require => [
      File[$dynamic_config_dir],
      File[$certificate_crt],
      File[$certificate_key],
    ],
  }

  file { $config_file:
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/traefik.yml.epp', {
      'dynamic_config_dir' => $dynamic_config_dir,
      'private_ip'         => $private_ip,
      'tcp_entry_points'   => $tcp_entry_points,
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
      Exec['require-traefik-binary'],
      User['traefik'],
      File[$config_file],
      File[$systemd_unit],
      File[$tls_config_file],
    ],
  }
}
