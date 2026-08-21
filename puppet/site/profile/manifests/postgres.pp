# @summary Configures PostgreSQL and its host-only Traefik TCP route.
class profile::postgres (
  Stdlib::Host $hostname,
  Stdlib::IP::Address $bind,
  Stdlib::Port $port,
  String[1] $route_entry_point,
  String[1] $postgres_password,
  Hash $keycloak_db,
  Hash $siloverse_db,
) {

  # pg_hba: one line per role↔database pair, no catch-all — the connection
  # layer refuses wrong-database attempts before SQL grants are consulted.
  $silo_acls = $siloverse_db['schemas'].map |$silo, $cfg| {
    "host ${siloverse_db['db']} ${cfg['username']} 127.0.0.1/32 scram-sha-256"
  }
  $keycloak_acl = "host ${keycloak_db['db']} ${keycloak_db['username']} 127.0.0.1/32 scram-sha-256"

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

  # ---- keycloak: its own database, unchanged pattern -----------------------
  postgresql::server::db { $keycloak_db['db']:
    user     => $keycloak_db['username'],
    owner    => $keycloak_db['username'],
    password => postgresql::postgresql_password($keycloak_db['username'], $keycloak_db['password']),
  }

  # ---- siloverse: shared database, schema-per-silo -------------------------
  postgresql::server::database { $siloverse_db['db']: }

  # Close PUBLIC's default CONNECT/TEMP. Idempotency probe: keycloak's role
  # has no direct grant here, so it can connect only via PUBLIC — once it
  # cannot, the revoke is in place.
  postgresql_psql { 'revoke public access on silos database':
    command => "REVOKE CONNECT, TEMPORARY ON DATABASE ${siloverse_db['db']} FROM PUBLIC",
    unless  => "SELECT 1 WHERE NOT has_database_privilege('${keycloak_db['username']}', '${siloverse_db['db']}
      ', 'CONNECT')",
    require => [
      Postgresql::Server::Database[$siloverse_db['db']],
      Postgresql::Server::Db[$keycloak_db['db']],
    ],
  }
  # No shared surface: cross-silo objects must have nowhere convenient to live.
  postgresql_psql { 'drop public schema in silos database':
    db      => $siloverse_db['db'],
    command => 'DROP SCHEMA public',
    onlyif  => "SELECT 1 FROM pg_namespace WHERE nspname = 'public'",
    require => Postgresql::Server::Database[$siloverse_db['db']],
  }

  $siloverse_db['schemas'].each |String $silo, Hash $cfg| {
    $role = $cfg['username']

    postgresql::server::role { $role:
      password_hash => postgresql::postgresql_password($role, $cfg['password']),
    }

    postgresql::server::database_grant { "${role}-connect":
      privilege => 'CONNECT',
      db        => $siloverse_db['db'],
      role      => $role,
      require   => [Postgresql::Server::Role[$role], Postgresql::Server::Database[$siloverse_db['db']]],
    }

    postgresql::server::schema { $silo:
      db      => $siloverse_db['db'],
      owner   => $role,
      require => [Postgresql::Server::Role[$role], Postgresql::Server::Database[$siloverse_db['db']]],
    }

  }

  traefik::tcp_route { 'postgres':
    entry_point => $route_entry_point,
    target      => "${bind}:${port}",
  }

  Class['postgresql::server'] -> Traefik::Tcp_route['postgres']
}
