# @summary Configures PostgreSQL and its host-only Traefik TCP route.
class profile::postgres (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $bind,
  Stdlib::Port $port,
  String[1] $route_entry_point,
  String[1] $postgres_password,
  String[1] $tinyurl_user,
  String[1] $tinyurl_password,
  String[1] $keycloak_user,
  String[1] $keycloak_password,
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

  postgresql::server::db { 'tinyurl':
    user     => $tinyurl_user,
    password => postgresql::postgresql_password($tinyurl_user, $tinyurl_password),
  }

  postgresql::server::db { 'keycloak':
    user     => $keycloak_user,
    owner    => $keycloak_user,
    password => postgresql::postgresql_password($keycloak_user, $keycloak_password),
  }

  traefik::tcp_route { 'postgres':
    entry_point => $route_entry_point,
    target      => "${bind}:${port}",
  }

  Class['postgresql::server'] -> Traefik::Tcp_route['postgres']
}
