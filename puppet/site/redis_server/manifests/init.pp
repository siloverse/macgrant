# @summary Installs and configures Redis with a Traefik TCP route.
#
# @param hostname
#   DNS hostname used to access Redis.
#
# @param bind
#   IP address on which Redis listens.
#
# @param port
#   Redis TCP port.
#
# @param password
#   Password required for Redis connections.
#
# @param traefik_dynamic_config_dir
#   Directory watched by Traefik for dynamic configuration.
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
