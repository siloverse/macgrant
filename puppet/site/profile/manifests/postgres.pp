# @summary Configures PostgreSQL and its host-only Traefik TCP route.
class profile::postgres (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $bind,
  Stdlib::Port $port,
  String[1] $route_entry_point,
  String[1] $postgres_password,
  Hash[String[1], Struct[{
    username => String[1],
    password => String[1],
  }]] $postgres_dbs = {},
) {
  class { 'postgresql::server':
    listen_addresses           => $bind,
    port                       => $port,
    ip_mask_deny_postgres_user => '0.0.0.0/32',
    ip_mask_allow_all_users    => '127.0.0.1/32',
    ipv4acls                   => ['host all all 127.0.0.1/32 scram-sha-256'],
    postgres_password          => $postgres_password,
  }

  contain postgresql::server

  # Services inside the VM bypass the host-only Traefik listener.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  $postgres_dbs.each |String[1] $db_name, Hash $db| {
    postgresql::server::db { $db_name:
      user     => $db['username'],
      owner    => $db['username'],
      password => postgresql::postgresql_password($db['username'], $db['password']),
    }
  }

  traefik::tcp_route { 'postgres':
    entry_point => $route_entry_point,
    target      => "${bind}:${port}",
  }

  Class['postgresql::server'] -> Traefik::Tcp_route['postgres']
}
