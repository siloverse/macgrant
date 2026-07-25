# @summary Configures Redis and its host-only Traefik TCP route.
class profile::redis (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $bind,
  Stdlib::Port $port,
  String[1] $route_entry_point,
  String[1] $password,
) {
  class { 'redis':
    bind        => $bind,
    port        => $port,
    requirepass => $password,
  }

  contain redis

  # Services inside the VM bypass the host-only Traefik listener.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  traefik::tcp_route { 'redis':
    entry_point => $route_entry_point,
    target      => "${bind}:${port}",
  }

  Class['redis'] -> Traefik::Tcp_route['redis']
}
