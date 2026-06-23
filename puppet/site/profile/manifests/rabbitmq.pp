# @summary Installs RabbitMQ and exposes AMQP and management through Traefik.
class profile::rabbitmq (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $amqp_address,
  Stdlib::Port $amqp_port,
  Stdlib::IP::Address $management_address,
  Stdlib::Port $management_port,
  String[1] $route_entry_point,
  String[1] $rabbitmq_package_version,
  String[1] $erlang_version_pattern,
  Pattern[/^[a-zA-Z0-9_.-]+$/] $username,
  Pattern[/^[a-zA-Z0-9_.-]+$/] $password,
  Pattern[/^[a-zA-Z0-9_.-]+$/] $vhost,
) {
  $signing_key = '/usr/share/keyrings/com.rabbitmq.team.gpg'

  $erlang_packages = [
    'erlang-base',
    'erlang-asn1',
    'erlang-crypto',
    'erlang-eldap',
    'erlang-ftp',
    'erlang-inets',
    'erlang-mnesia',
    'erlang-os-mon',
    'erlang-parsetools',
    'erlang-public-key',
    'erlang-runtime-tools',
    'erlang-snmp',
    'erlang-ssl',
    'erlang-syntax-tools',
    'erlang-tftp',
    'erlang-tools',
    'erlang-xmerl',
  ]

  unless $facts['os']['architecture'] in ['amd64', 'x86_64'] {
    fail('The configured Team RabbitMQ Erlang repository supports amd64 only')
  }

  package { [
    'gnupg',
    'apt-transport-https',
  ]:
    ensure => installed,
  }

  exec { 'install-rabbitmq-signing-key':
    command => '/bin/bash -c "/usr/bin/curl -1sLf https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA | /usr/bin/gpg --dearmor --yes --output /usr/share/keyrings/com.rabbitmq.team.gpg"',
    creates => $signing_key,
    require => [
      Package['curl'],
      Package['gnupg'],
    ],
    notify  => Exec['update-rabbitmq-package-index'],
  }

  file { '/etc/apt/sources.list.d/rabbitmq.list':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/rabbitmq.list.epp', {
      'codename' => $facts['os']['distro']['codename'],
    }),
    require => Exec['install-rabbitmq-signing-key'],
    notify  => Exec['update-rabbitmq-package-index'],
  }

  file { '/etc/apt/preferences.d/rabbitmq-erlang':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/rabbitmq-erlang.pref.epp', {
      'version_pattern' => $erlang_version_pattern,
    }),
    notify  => Exec['update-rabbitmq-package-index'],
  }

  file { '/etc/apt/preferences.d/rabbitmq-server':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/rabbitmq-server.pref.epp', {
      'package_version' => $rabbitmq_package_version,
    }),
    notify  => Exec['update-rabbitmq-package-index'],
  }

  exec { 'update-rabbitmq-package-index':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
  }

  package { $erlang_packages:
    ensure  => installed,
    require => Exec['update-rabbitmq-package-index'],
  }

  package { 'rabbitmq-server':
    ensure  => $rabbitmq_package_version,
    require => [
      Exec['update-rabbitmq-package-index'],
      Package['erlang-base'],
      Package['erlang-ssl'],
    ],
  }

  file { '/etc/rabbitmq/rabbitmq.conf':
    ensure  => file,
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0640',
    content => epp('profile/rabbitmq.conf.epp', {
      'amqp_address'       => $amqp_address,
      'amqp_port'          => $amqp_port,
      'management_address' => $management_address,
      'management_port'    => $management_port,
    }),
    require => Package['rabbitmq-server'],
    notify  => Service['rabbitmq-server'],
  }

  file { '/etc/rabbitmq/enabled_plugins':
    ensure  => file,
    owner   => 'rabbitmq',
    group   => 'rabbitmq',
    mode    => '0640',
    content => "[rabbitmq_management].\n",
    require => Package['rabbitmq-server'],
    notify  => Service['rabbitmq-server'],
  }

  service { 'rabbitmq-server':
    ensure   => running,
    enable   => true,
    provider => 'systemd',
    require  => [
      Package['rabbitmq-server'],
      File['/etc/rabbitmq/rabbitmq.conf'],
      File['/etc/rabbitmq/enabled_plugins'],
    ],
  }

  exec { 'create-macgrant-rabbitmq-vhost':
    command => "/usr/sbin/rabbitmqctl add_vhost '${vhost}'",
    unless  => "/usr/sbin/rabbitmqctl list_vhosts | /usr/bin/grep -Fxq '${vhost}'",
    require => Service['rabbitmq-server'],
  }

  exec { 'create-macgrant-rabbitmq-user':
    command   => "/usr/sbin/rabbitmqctl add_user '${username}' '${password}'",
    unless    => "/usr/sbin/rabbitmqctl list_users | /usr/bin/cut -f1 | /usr/bin/grep -Fxq '${username}'",
    logoutput => false,
    require   => Service['rabbitmq-server'],
  }

  exec { 'synchronize-macgrant-rabbitmq-password':
    command   => "/usr/sbin/rabbitmqctl change_password '${username}' '${password}'",
    unless    => "/usr/sbin/rabbitmqctl authenticate_user '${username}' '${password}'",
    logoutput => false,
    require   => Exec['create-macgrant-rabbitmq-user'],
  }

  exec { 'set-macgrant-rabbitmq-user-tags':
    command => "/usr/sbin/rabbitmqctl set_user_tags '${username}' administrator",
    unless  => "/usr/sbin/rabbitmqctl list_users | /usr/bin/grep -Eq '^${username}[[:space:]]+\\[administrator\\]'",
    require => Exec['synchronize-macgrant-rabbitmq-password'],
  }

  exec { 'set-macgrant-rabbitmq-permissions':
    command => "/usr/sbin/rabbitmqctl set_permissions -p '${vhost}' '${username}' '.*' '.*' '.*'",
    unless  => "/usr/sbin/rabbitmqctl list_permissions -p '${vhost}' | /usr/bin/grep -Eq '^${username}[[:space:]]+\\.\\*[[:space:]]+\\.\\*[[:space:]]+\\.\\*'",
    require => [
      Exec['create-macgrant-rabbitmq-vhost'],
      Exec['set-macgrant-rabbitmq-user-tags'],
    ],
  }

  exec { 'remove-default-rabbitmq-guest-user':
    command => '/usr/sbin/rabbitmqctl delete_user guest',
    onlyif  => "/usr/sbin/rabbitmqctl list_users | /usr/bin/cut -f1 | /usr/bin/grep -Fxq 'guest'",
    require => Exec['set-macgrant-rabbitmq-permissions'],
  }

  # Services inside the VM bypass the host-only Traefik entry point.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  traefik::tcp_route { 'rabbitmq':
    entry_point => $route_entry_point,
    target      => "${amqp_address}:${amqp_port}",
  }

  traefik::http_route { 'rabbitmq-management':
    hostname => $hostname,
    target   => "http://${management_address}:${management_port}",
    tls      => true,
  }

  Service['rabbitmq-server'] -> Traefik::Tcp_route['rabbitmq']
  Service['rabbitmq-server'] -> Traefik::Http_route['rabbitmq-management']
}