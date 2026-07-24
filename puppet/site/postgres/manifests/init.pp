# @summary Configures PostgreSQL with a Traefik TCP route.
#
# @param hostname
#   DNS hostname used to access PostgreSQL.
#
# @param bind
#   IP address on which PostgreSQL listens.
#
# @param port
#   PostgreSQL TCP port.
#
# @param traefik_dynamic_config_dir
#   Directory watched by Traefik for dynamic configuration.
class postgres (
  String  $hostname                   = 'postgres.macgrant-platform.test',
  String  $bind                       = '127.0.0.1',
  Integer $port                       = 5432,
  String  $traefik_dynamic_config_dir = '/etc/traefik/dynamic',
) {
  class { 'postgresql::server':
    listen_addresses           => $bind,
    port                       => $port,
    ip_mask_deny_postgres_user => '0.0.0.0/32',
    ip_mask_allow_all_users    => '127.0.0.1/32',
    ipv4acls                   => ['host all all 127.0.0.1/32 scram-sha-256'],
    postgres_password          => '123123',
  }

  # Inside the VM, the hostname resolves directly to local PostgreSQL.
  host { $hostname:
    ensure => present,
    ip     => '127.0.0.1',
  }

  postgresql::server::db { 'tinyurl':
    user     => 'tinyurl_user',
    password => postgresql::postgresql_password('tinyurl_user', 'tinyurl_password'),
  }

  postgresql::server::db { 'keycloak':
    user     => 'keycloak_user',
    owner    => 'keycloak_user',
    password => postgresql::postgresql_password('keycloak_user', 'keycloak_password'),
  }

  file { "${traefik_dynamic_config_dir}/postgres.yml":
    ensure  => file,
    owner   => 'root',
    group   => 'traefik',
    mode    => '0640',
    content => epp('traefik/tcp_route.yml.epp', {
        'route_name'  => 'postgres',
        'entry_point' => 'postgres',
        'target'      => "${bind}:${port}",
    }),
    require => [
      Class['postgresql::server'],
      Class['traefik'],
    ],
  }
}
