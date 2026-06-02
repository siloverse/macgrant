class redis_server (
  String  $hostname                   = 'redis.macgrant-platform.test',
  String  $bind                       = '127.0.0.1',
  Integer $port                       = 6379,
  String  $password                   = 'secret',
  String  $traefik_dynamic_config_dir = '/etc/traefik/dynamic',
) {
  class { 'redis':
    bind        => $bind,
    port        => $port,
    requirepass => $password,
  }

  # Inside the VM, the hostname resolves directly to local Redis.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  file { "${traefik_dynamic_config_dir}/redis.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/tcp_route.yml.epp', {
      'route_name'  => 'redis',
      'entry_point' => 'redis',
      'target'      => "${bind}:${port}",
    }),
    require => [
      Class['redis'],
      Class['traefik'],
    ],
  }
}